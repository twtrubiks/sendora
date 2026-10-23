require "test_helper"

class TeamDestroyJobTest < ActiveJob::TestCase
  test "刪掉團隊與其所有資料,不影響其他團隊" do
    team = teams(:acme)
    campaign = campaigns(:acme_draft)
    campaign.deliveries.create!(team: team, customer: customers(:acme_tom), status: :sent)
    import_job = team.import_jobs.create!(user: users(:alice), kind: :customers, filename: "c.csv",
                                          file: { io: StringIO.new("email\n"), filename: "c.csv" })
    import_job.import_failures.create!(line_number: 2, message: "壞資料")

    TeamDestroyJob.perform_now(team)

    assert_not Team.exists?(team.id)
    [ Membership, Customer, Order, Tag, Audience, Campaign, Delivery, ImportJob ].each do |model|
      assert_not model.exists?(team_id: team.id), "#{model} 還有殘留"
    end
    assert_not ImportFailure.exists?(import_job_id: import_job.id)
    assert Team.exists?(slug: "globex")
    assert customers(:globex_tom).reload
  end

  test "團隊已經不在時直接略過" do
    team = teams(:globex)
    TeamDestroyJob.perform_later(team)
    team.destroy!

    assert_nothing_raised { perform_enqueued_jobs }
  end
end
