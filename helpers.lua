-- helpers.lua
function SendToPeers(id)
  local command = {}
  command['Resources'] = {id}
  command['Asynchronous'] = true
  RestApiPost('/peers/<peer>/store', DumpJson(command, true) )
  RestApiPost('/modalities/<modality>/store', DumpJson(command, true))
end

-- Request Matcher
function RequestMatcher(Ip, Port, rawPatientName, rawPatientBirthDate, rawStudyDate)

  local PatientName = Normalize(rawPatientName)
  local PatientBirthDate = Normalize(rawPatientBirthDate)
  local StudyDate = Normalize(rawStudyDate)
  SetHttpTimeout(1)
  local matcherResponse = HttpGet("http://" .. Ip .. ':' .. Port .. "/study/" .. PatientBirthDate .. "/" .. PatientName .. "/" .. StudyDate)

  if (matcherResponse == '' or matcherResponse == nil) then return 404 end

  return ParseJson(matcherResponse)
end

-- Normalize string
function Normalize(someString)
  return string.gsub(string.lower(someString), '%s+', '')
end

-- Send matching study to peers
function SendMatchingStudy(patientOrthancID, targetStudyID)
  -- Get patient details
  local patientDetails = ParseJson(RestApiGet('/patients/' .. patientOrthancID))

  -- Loop through the studies of the patient
  for _, studyOrthancID in ipairs(patientDetails['Studies']) do
    -- Get study details
    local studyDetails = ParseJson(RestApiGet('/studies/' .. studyOrthancID))

    -- Check if the current study's StudyID matches the targetStudyID
    if studyDetails['MainDicomTags']['StudyID'] == targetStudyID then
      -- Send the matching study to peers
      SendToPeers(studyOrthancID)
      break
    end
  end
end
