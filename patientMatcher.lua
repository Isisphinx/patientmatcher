function OnStableStudy(studyId, tags, metadata)
  if (stationName == "SCANNER" and physicianName ~= "A") then return end
  
  -- Return early if study is already rectified
  if metadata['1024'] == 'rectified' then return end

  -- get environment variables port and ip
  local matcherIp = os.getenv('matcherIp')
  local matcherPort = os.getenv('matcherPort')

  -- Get study details
  local studyDetails = RestApiGet('/studies/' .. studyId)
  local studyJson = ParseJson(studyDetails)

  -- Get patient details
  local patientID = studyJson['ParentPatient']
  local patientDetails = RestApiGet('/patients/' .. patientID)
  local patientJson = ParseJson(patientDetails)

  -- Get patient name and birth date
  local patientName = patientJson['MainDicomTags']['PatientName']
  local patientBirthDate = patientJson['MainDicomTags']['PatientBirthDate']

  local matcherResponse = RequestMatcher(matcherIp, matcherPort, patientName, patientBirthDate, tags['StudyDate'])

  -- Send Study without modification if not found in database and return early
  if (matcherResponse == 404) then
    SendToPeers(studyId)
    return
  end

  -- Settup command for study modification
  local replace = {}
  replace['PatientID'] = matcherResponse['patientid']
  replace['AccessionNumber'] = matcherResponse['studyid']
  replace['StudyInstanceUID'] = matcherResponse['studyinstanceuid']
  local command = {}
  command['Replace'] = replace
  command['Force'] = true
  
  -- Modify study and get new studyId 
  local modifiedStudyId = ParseJson(RestApiPost('/studies/' .. studyId .. '/modify', DumpJson(command, true)))['ID']
  -- Mark study as rectified
  RestApiPut('/studies/' .. modifiedStudyId .. '/metadata/1024', 'rectified')

  -- Delete original study
  RestApiDelete('/studies/' .. studyId)
  -- Send rectified study to peers
  SendToPeers(modifiedStudyId)
end

-- Request Matcher
function RequestMatcher(Ip, Port, rawPatientName, rawPatientBirthDate, rawStudyDate)
  local matcherUrlTemplate = 'http://{ip}:{port}/study/{PatientBirthDate}/{PatientName}/{StudyDate}'

  local PatientName = Normalize(rawPatientName)
  local PatientBirthDate = Normalize(rawPatientBirthDate)
  local StudyDate = Normalize(rawStudyDate)

  local matcherUrl = InterpolateString(matcherUrlTemplate, {
    ip = Ip,
    port = Port,
    PatientBirthDate = PatientBirthDate,
    PatientName = PatientName,
    StudyDate = StudyDate
  })
  local matcherResponse = HttpGet(matcherUrl)

  if (matcherResponse == '' or matcherResponse == nil) then return 404 end

  return ParseJson(matcherResponse)
end

--
-- Helper functions
--

-- Send study to multiple peers
function SendToPeers(id)
--   RestApiPost('/peers/<peer>/store', id )
--   RestApiPost('/modalities/<modality>/store', id)
end

-- Interpolate string with variables
function InterpolateString(str, variables)
  return (str:gsub('({%w+})', function(match)
    local key = match:sub(2, -2)
    return variables[key] or match
  end))
end

-- Normalize string
function Normalize(someString)
  return string.gsub(string.lower(someString), '%s+', '')
end
