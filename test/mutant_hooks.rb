# mutant 的 worker 平行跑變異,每個 worker 各用一個測試 DB(sendora_test_mutant_N),
# 避免 fixtures 與交易互相干擾
hooks.register(:mutation_worker_process_start) do |index:|
  ActiveRecord::TestDatabases.create_and_load_schema("mutant_#{index}", env_name: "test")
end

# `mutant test run` 也會平行跑測試,同樣各用一個 DB
hooks.register(:test_worker_process_start) do |index:|
  ActiveRecord::TestDatabases.create_and_load_schema("mutant_test_#{index}", env_name: "test")
end
