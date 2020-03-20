function OnStoredInstance(instanceId, tags, metadata, origin)

  -- Prevent infinite loop
  if origin["RequestOrigin"] ~= "Lua" then
    local patientName = string.lower(tags["PatientName"])
    local PatientBirthDate = string.lower(tags["PatientBirthDate"])
    local StudyDate = string.lower(tags["StudyDate"])

    local response = HttpGet("http://<IP:PORT>/study/" .. PatientBirthDate .. "/" .. patientName .. "/" .. StudyDate)
    print(response)

    -- only modify if patient match
    if (response ~= "" and response ~= nil )then
      local parsedResponse = ParseJson(response)

      local replace = {}
      replace["PatientID"] = parsedResponse["patientid"]
      replace["AccessionNumber"] = parsedResponse["studyid"]

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
