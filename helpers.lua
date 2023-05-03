-- helpers.lua
function SendToPeers(id)
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
function SendMatchingStudy(patientOrthancID, targetStudyInstanceUID)
  -- Get patient details
  local patientDetails = ParseJson(RestApiGet('/patients/' .. patientOrthancID))

  -- Loop through the studies of the patient
  for _, studyOrthancID in ipairs(patientDetails['Studies']) do
    -- Get study details with requestedTags query parameter
    local requestedTags = 'StudyInstanceUID'
    local studyDetails = ParseJson(RestApiGet('/studies/' .. studyOrthancID .. '?requestedTags=' .. requestedTags))

    -- Check if the current study's StudyInstanceUID matches the targetStudyInstanceUID
    if studyDetails['MainDicomTags']['StudyInstanceUID'] == targetStudyInstanceUID then
      -- Send the matching study to peers
      SendToPeers(studyOrthancID)
      break
    end
  end
end
