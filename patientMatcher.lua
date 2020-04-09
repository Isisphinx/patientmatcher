function OnStoredInstance(instanceId, tags, metadata, origin)
  -- Prevent infinite loop
  if origin["RequestOrigin"] ~= "Lua" then
    local PatientName = string.lower(tags["PatientName"])
    local PatientBirthDate = string.lower(tags["PatientBirthDate"])
    local StudyDate = string.lower(tags["StudyDate"])
    local newSeriesInstanceUID = string.lower(tags["SeriesInstanceUID"]) .. ".2"
    local newSOPInstanceUID = string.lower(tags["SOPInstanceUID"]) .. ".2"

    local response = HttpGet("http://<IP:PORT>/study/" .. PatientBirthDate .. "/" .. PatientName .. "/" .. StudyDate)
    -- only modify if patient match
    if (response ~= "" and response ~= nil) then
      local parsedResponse = ParseJson(response)
      local replace = {}
      replace["PatientID"] = parsedResponse["patientid"]
      replace["AccessionNumber"] = parsedResponse["studyid"]
      replace["StudyInstanceUID"] = parsedResponse["studyinstanceuid"]
      replace["SeriesInstanceUID"] = newSeriesInstanceUID
      replace["SOPInstanceUID"] = newSOPInstanceUID

      -- modify instance
      local command = {}
      command["Replace"] = replace
      command["Force"] = true
      local modifiedFile = RestApiPost("/instances/" .. instanceId .. "/modify", DumpJson(command, true))
      -- Upload the modified instance to the Orthanc database so that
      -- it can be sent by Orthanc to other modalities
      local modifiedId = ParseJson(RestApiPost("/instances/", modifiedFile))["ID"]
      -- Send the modified instance to another modality
      RestApiPost("/peers/<PEER_NAME>/store", modifiedId)
      -- Delete the original
      RestApiDelete("/instances/" .. instanceId)
    else
      RestApiPost("/peers/<PEER_NAME>/store", instanceId)
    end
  end
end
