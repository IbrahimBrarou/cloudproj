require "test_helper"

class VmBuildControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get vm_build_create_url
    assert_response :success
  end
end
