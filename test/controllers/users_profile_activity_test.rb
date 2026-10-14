require "test_helper"

class UsersProfileActivityTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(slack_id: "U_PA_ADMIN", display_name: "pa_admin", verified: true)
    @admin.grant_role!(:admin)
    @owner = create_user(slack_id: "U_PA_OWNER", display_name: "pa_owner", verified: true)

    @project = Project.create!(title: "Starry Project", marked_fire_at: Time.current, marked_fire_by: @admin)
    @project.memberships.create!(user: @owner, role: :owner)
    Post.create!(project: @project, user: @admin, postable: Post::FireEvent.create!)
  end

  test "super star post is not shown on the granting admin's profile" do
    sign_in @admin

    get user_path(@admin)

    assert_response :success
    assert_select ".feed-post-card--fire", 0
  end

  test "project mission badges load without a query per project" do
    add_mission_project = lambda do |i|
      mission = Mission.create!(slug: "badge-#{i}", name: "Badge #{i}", description: "Mission #{i}")
      mission.icon.attach(io: StringIO.new(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=")), filename: "icon.png", content_type: "image/png")
      project = Project.create!(title: "Mission project #{i}")
      project.memberships.create!(user: @owner, role: :owner)
      project.mission_attachments.create!(mission: mission, attached_at: Time.current)
    end
    # `WHERE id = $1`-style lookups per table, the shape a per-project N+1 takes.
    single_row_lookups = lambda do
      counts = Hash.new(0)
      callback = lambda do |*, payload|
        table = payload[:sql][/\ASELECT .* FROM "(\w+)" WHERE "\1"\."\w+" = \$1/, 1]
        counts[table] += 1 if table
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get user_path(@owner, tab: "projects") }
      counts
    end

    1.upto(2) { |i| add_mission_project.call(i) }
    get user_path(@owner, tab: "projects")
    few = single_row_lookups.call

    3.upto(4) { |i| add_mission_project.call(i) }
    many = single_row_lookups.call

    assert_response :success
    assert_select ".profile-project-card__mission-badge-icon", 4
    assert_equal few, many
  end

  test "super star post is still shown on the project" do
    sign_in @admin

    get project_path(@project)

    assert_response :success
    assert_select ".feed-post-card--fire", 1
  end
end
