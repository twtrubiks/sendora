class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :team, :membership
  delegate :user, to: :session, allow_nil: true
end
