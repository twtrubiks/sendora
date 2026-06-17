class CampaignsController < ApplicationController
  include TeamContext
  before_action :set_campaign, only: %i[ show edit update confirm deliver duplicate destroy ]
  before_action :require_draft!, only: %i[ edit update confirm deliver destroy ]
  before_action :require_audiences!, only: %i[ new create ]

  def index
    @pagy, @campaigns = pagy(Current.team.campaigns.includes(:audience).order(created_at: :desc))
  end

  def show
    if @campaign.draft?
      redirect_to edit_campaign_path(@campaign)
      return
    end

    stats = @campaign.deliveries.group(:status).count
    @sent_count = stats["sent"].to_i
    @failed_count = stats["failed"].to_i
    @pending_count = stats["pending"].to_i

    respond_to do |format|
      format.html { @pagy, @failed_deliveries = pagy(@campaign.deliveries.failed.includes(:customer).order(:id)) }
      format.csv { stream_deliveries_csv }
    end
  end

  def new
    @campaign = Current.team.campaigns.new
  end

  def create
    @campaign = Current.team.campaigns.new(campaign_params)

    if @campaign.save
      redirect_to confirm_campaign_path(@campaign), notice: "草稿已儲存,請確認後發送"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @campaign.update(campaign_params)
      redirect_to confirm_campaign_path(@campaign), notice: "草稿已更新,請確認後發送"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # 發送確認頁:全產品唯一需要「隆重確認」的地方
  def confirm
    @recipients_count = @campaign.recipients.count
    @remaining_quota = Current.team.remaining_quota
    @can_send = @recipients_count.positive? && Current.team.can_send?(@recipients_count)
  end

  def deliver
    recipients_count = @campaign.recipients.count

    if recipients_count.zero?
      redirect_to confirm_campaign_path(@campaign), alert: "此分群目前沒有可寄送的客戶"
    elsif !Current.team.can_send?(recipients_count)
      redirect_to confirm_campaign_path(@campaign), alert: "超出本月發送額度,請聯絡管理者調整"
    else
      @campaign.update!(status: :sending)
      CampaignSendJob.perform_later(@campaign)
      redirect_to campaign_path(@campaign), notice: "已開始發送,完成後狀態會自動更新"
    end
  end

  def duplicate
    copy = @campaign.duplicate

    if copy.save
      redirect_to edit_campaign_path(copy), notice: "已複製活動,可直接修改後發送"
    else
      redirect_to campaigns_path, alert: copy.errors.full_messages.to_sentence
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_path, notice: "草稿已刪除", status: :see_other
  end

  private
    def set_campaign
      @campaign = Current.team.campaigns.find(params[:id])
    end

    def require_draft!
      redirect_to campaign_path(@campaign), alert: "只有草稿可以執行此操作" unless @campaign.draft?
    end

    def require_audiences!
      if Current.team.audiences.none?
        redirect_to audiences_path, alert: "建立活動前,請先建立一個分群"
      end
    end

    def campaign_params
      params.expect(campaign: [ :name, :audience_id, :subject, :body ])
    end

    def stream_deliveries_csv
      response.headers["Content-Type"] = "text/csv; charset=utf-8"
      response.headers["Content-Disposition"] = %(attachment; filename="campaign_#{@campaign.id}_deliveries.csv")
      deliveries = @campaign.deliveries.includes(:customer).order(:id)
      self.response_body = Enumerator.new do |yielder|
        yielder << CSV.generate_line([ "email", "status", "error", "sent_at" ])
        deliveries.find_each do |delivery|
          yielder << CSV.generate_line([ delivery.customer.email, delivery.status,
                                         delivery.error_message, delivery.sent_at&.strftime("%Y-%m-%d %H:%M:%S") ])
        end
      end
    end
end
