-- patientMatcher.lua
local helpers = require('<path>/helpers')
local config = require('<path>/config')

function OnStableStudy(studyOrthancID, tags, metadata)
  local stationName = metadata['StationName']
  local physicianName = metadata['PhysicianName']
  if (stationName == 'SCANNER' and physicianName ~= 'A') then return end

  -- Return early if study is already rectified using the custom DICOM tag
  if tags['0011,0010'] == 'rectified' then return end

  -- Get port and ip
  local matcherIp = config.matcherIp
  local matcherPort = config.matcherPort

  -- Get study details with requestedTags query parameter
  local requestedTags = 'PatientName,PatientBirthDate,StudyDate,ParentPatient'
  local studyDetails = ParseJson(RestApiGet('/studies/' .. studyOrthancID))

  -- Get patient name, birth date, and study date directly from the studyDetails
  local patientName = studyDetails['PatientMainDicomTags']['PatientName']
  local patientBirthDate = studyDetails['PatientMainDicomTags']['PatientBirthDate']
  local studyDate = studyDetails['MainDicomTags']['StudyDate']
  local patientOrthancID = studyDetails['ParentPatient']

  local matcherResponse = RequestMatcher(matcherIp, matcherPort, patientName, patientBirthDate, studyDate)

  -- Send Study without modification if not found in database and return early
  if (matcherResponse == 404) then
    SendToPeers(studyOrthancID)
    return
  end

  -- Modify the study and mark it as rectified using the custom DICOM tag
  local studyReplace = {}
  studyReplace['StudyID'] = matcherResponse['studyid']
  studyReplace['StudyInstanceUID'] = matcherResponse['studyinstanceuid']
  studyReplace['0011,0010'] = 'rectified'
  local studyCommand = {}
  studyCommand['Replace'] = studyReplace
  studyCommand['Force'] = true
  studyCommand['KeepSource'] = false
  local modifiedStudyOrthancID = ParseJson(RestApiPost('/studies/' .. studyOrthancID.. '/modify', DumpJson(studyCommand, true)))['ID']

  -- Modify patient ID
  local patientReplace = {}
  patientReplace['PatientID'] = matcherResponse['patientid']
  local patientCommand = {}
  patientCommand['Replace'] = patientReplace
  patientCommand['Force'] = true
  patientCommand['KeepSource'] = false
  local modifiedPatientOrthancID = ParseJson(RestApiPost('/patients/' .. patientOrthancID .. '/modify', DumpJson(patientCommand, true)))['ID']

  -- Send rectified study to peers
  SendMatchingStudy(modifiedPatientOrthancID, matcherResponse['studyinstanceuid'])
end
