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
  local studyDate = tags['StudyDate']

  local matcherResponse = RequestMatcher(matcherIp, matcherPort, patientName, patientBirthDate, studyDate)

  -- Send Study without modification if not found in database and return early
  if (matcherResponse == 404) then
    SendToPeers(studyId)
    return
  end
  
  -- Mark study as rectified
  RestApiPut('/studies/' .. modifiedStudyId .. '/metadata/1024', 'rectified')

  -- Set up command for patient modification
  local patientReplace = {}
  patientReplace['PatientID'] = matcherResponse['patientid']
  local patientCommand = {}
  patientCommand['Replace'] = patientReplace
  patientCommand['Force'] = true
  patientCommand['KeepSource'] = false

  -- Modify patient and get new patientId
  local modifiedPatientId = ParseJson(RestApiPost('/patients/' .. patientID .. '/modify', DumpJson(patientCommand, true)))['ID']

  -- Set up command for study modification
  local studyReplace = {}
  studyReplace['StudyInstanceUID'] = matcherResponse['studyinstanceuid']
  local studyCommand = {}
  studyCommand['Replace'] = studyReplace
  studyCommand['Force'] = true
  studyCommand['KeepSource'] = false

  -- Modify study and get new studyId
  local modifiedStudyId = ParseJson(RestApiPost('/studies/' .. studyId .. '/modify', DumpJson(studyCommand, true)))['ID']

  -- Send rectified study to peers
  SendToPeers(modifiedStudyId)
end
