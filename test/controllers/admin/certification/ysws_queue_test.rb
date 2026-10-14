require "test_helper"

# The GOI goes first, so its queue lists every pending review. Integrity waits on
# the GOI instead (Certification::Integrity.past_goi).
class Admin::Certification::YswsQueueTest < ActionDispatch::IntegrationTest
  include UserFactory

  setup do
    @admin = create_user(slack_id: "U_YSWS_QUEUE_ADMIN", display_name: "ysws_queue_admin")
    @admin.grant_role!(:admin)
    @shipper = create_user(slack_id: "U_YSWS_QUEUE_SHIPPER", display_name: "ysws_queue_shipper")
  end

  test "a review whose integrity check is still pending is in the queue" do
    review = pending_review(integrity: :pending)

    sign_in @admin
    get admin_certification_ysws_reviews_path

    assert_response :success
    assert_select "a[href=?]", admin_certification_ysws_review_path(review)
  end

  test "a review with no integrity check yet is in the queue" do
    review = pending_review(integrity: nil)

    sign_in @admin
    get admin_certification_ysws_reviews_path

    assert_select "a[href=?]", admin_certification_ysws_review_path(review)
  end

  test "the old integrity-only toggle is gone" do
    pending_review(integrity: :pending)

    sign_in @admin
    get admin_certification_ysws_reviews_path(with_integrity: "1")

    assert_response :success
    assert_select "#filter-with-integrity", count: 0
  end

  test "review flow includes reviews still waiting on integrity" do
    review = pending_review(integrity: :pending)
    Flipper.enable(:ysws_review_flow, @admin)

    sign_in @admin
    post next_admin_certification_ysws_reviews_path, params: { flow: 1, step: 1 }

    assert_redirected_to admin_certification_ysws_review_path(review, flow: 1, step: 1)
    assert review.reload.claimed_by?(@admin)
  ensure
    Flipper.disable(:ysws_review_flow, @admin)
  end

  test "review flow respects the queue age sort" do
    older = pending_review(integrity: nil)
    newer = pending_review(integrity: nil)
    older.update!(created_at: 2.days.ago)
    newer.update!(created_at: 1.day.ago)
    Flipper.enable(:ysws_review_flow, @admin)

    sign_in @admin
    get admin_certification_ysws_reviews_path(sort: "age", dir: "desc")
    post next_admin_certification_ysws_reviews_path, params: { flow: 1, step: 1 }

    assert_redirected_to admin_certification_ysws_review_path(newer, flow: 1, step: 1)
  ensure
    Flipper.disable(:ysws_review_flow, @admin)
  end

  private

  def pending_review(integrity:)
    project = Project.create!(title: "GOI queue #{SecureRandom.hex(4)}")
    Project::Membership.create!(project: project, user: @shipper, role: :owner)
    ship_event = Post::ShipEvent.create!(body: "Ship it", uploading_attachments: true)
    Post.create!(project: project, user: @shipper, postable: ship_event)
    Certification::Integrity.create!(ship_event: ship_event, status: integrity) if integrity
    Certification::Ysws.create!(user: @shipper, project: project, post_ship_event: ship_event, original_minutes: 60)
  end
end
