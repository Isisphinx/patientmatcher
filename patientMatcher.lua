local helpers = require('helpers')
local config = require("config")

function OnStableStudy(studyId, tags, metadata)
  if (stationName == "SCANNER" and physicianName ~= "A") then return end

  -- Return early if study is already rectified
  if metadata['1024'] == 'rectified' then return end

  -- get port and ip
  local matcherIp = config.matcherIp
  local matcherPort = config.matcherPort

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

  -- Set up command for patient modification
  local replace = {}
  replace['PatientID'] = matcherResponse['patientid']
  local command = {}
  command['Replace'] = replace
  command['Force'] = true

  -- Modify patient and get new patientId
  local modifiedPatientId = ParseJson(RestApiPost('/patients/' .. patientID .. '/modify', DumpJson(command, true)))['ID']

  -- Send rectified study to peers
  SendToPeers(studyId)
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
