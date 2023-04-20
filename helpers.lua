function SendToPeers(id)
  command['Resources'] = {id}
  command['Asynchronous'] = true
  RestApiPost('/peers/<peer>/store', DumpJson(command, true) )
  RestApiPost('/modalities/<modality>/store', DumpJson(command, true))
end
