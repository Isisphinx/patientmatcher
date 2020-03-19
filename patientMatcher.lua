function OnStoredInstance(instanceId, tags, metadata, origin)
  -- Prevent infinite loop
  if origin['RequestOrigin'] ~= 'Lua' then
    local patientName = string.lower(tags["PatientName"])
    local PatientBirthDate = string.lower(tags["PatientBirthDate"])
    local response = HttpGet("http://192.168.0.181:8080/patient/" .. PatientBirthDate .. "/" .. patientName)
    print(response)

    -- only modify if patient match
    if response ~= nil then
      local replace = {}
      replace["PatientID"] = response

      -- modify instance
      local command = {}
      command['Replace'] = replace
      command['Force'] = true
      
      local modifiedFile = RestApiPost('/instances/' .. instanceId .. '/modify', DumpJson(command, true))

      -- Upload the modified instance to the Orthanc database so that
      -- it can be sent by Orthanc to other modalities
      local modifiedId = ParseJson(RestApiPost('/instances/', modifiedFile)) ['ID']

      RestApiDelete('/instances/' .. instanceId)
    end
  end
end
