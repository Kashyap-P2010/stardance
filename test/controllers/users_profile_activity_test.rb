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

  test "super star post is still shown on the project" do
    sign_in @admin

    get project_path(@project)

    assert_response :success
    assert_select ".feed-post-card--fire", 1
  end

  test "like buttons read one precomputed set, reposted devlogs included" do
    viewer = create_user(slack_id: "U_PA_VIEWER", display_name: "pa_viewer", verified: true)
    liked = 2.times.map { |i| Post.create!(project: @project, user: @owner, postable: build_devlog("Liked #{i}")) }
    Post.create!(project: @project, user: @owner, postable: build_devlog("Not liked"))

    author = create_user(slack_id: "U_PA_AUTHOR", display_name: "pa_author", verified: true)
    other_project = Project.create!(title: "Other Project")
    other_project.memberships.create!(user: author, role: :owner)
    original = Post.create!(project: other_project, user: author, postable: build_devlog("Reposted"))
    Post.create!(user: @owner, postable: Post::Repost.create!(original_post: original, user: @owner))

    [ *liked, original ].each { |post| Like.create!(user: viewer, likeable: post.postable) }
    sign_in viewer

    assert_queries_match(/SELECT 1 AS one FROM "likes"/, count: 0) do
      get user_path(@owner)
    end

    assert_response :success
    assert_select ".like-button__btn--liked", 3
    assert_select ".like-button__btn:not(.like-button__btn--liked)", 1
  end

  private
    def build_devlog(body)
      devlog = Post::Devlog.new(body: body, duration_seconds: 1.hour)
      devlog.uploading_attachments = true
      devlog.save!
      devlog
    end
end
