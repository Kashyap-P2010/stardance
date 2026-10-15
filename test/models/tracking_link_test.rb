require "test_helper"

class TrackingLinkTest < ActiveSupport::TestCase
  test "nothing to link without a code" do
    assert_nil TrackingLink.for(nil)
    assert_nil TrackingLink.for("  ")
  end

  test "a pasted tracking url links to itself under a friendly label" do
    link = TrackingLink.for("https://parcelsapp.com/en/tracking/ABC123")

    assert_equal "https://parcelsapp.com/en/tracking/ABC123", link.url
    assert_equal TrackingLink::URL_LABEL, link.label
  end

  test "a non-web scheme is never treated as a url" do
    link = TrackingLink.for("javascript:alert(1)")

    assert_nil link.url
    assert_equal "javascript:alert(1)", link.label
  end

  test "hack club mail ids link to mail.hackclub.com" do
    assert_equal "https://mail.hackclub.com/pkg!abc123", TrackingLink.for("pkg!abc123").url
    assert_equal "https://mail.hackclub.com/ltr!xyz", TrackingLink.for("ltr!xyz").url
  end

  test "recognisable carrier numbers link to the carrier" do
    {
      "9400 1000 0000 0000 0000 00" => "https://tools.usps.com/go/TrackConfirmAction?tLabels=9400100000000000000000",
      "1z999aa10123456784" => "https://www.ups.com/track?tracknum=1Z999AA10123456784",
      "AB123456789GB" => "https://www.royalmail.com/track-your-item#/tracking-results/AB123456789GB",
      "CD123456789AU" => "https://auspost.com.au/mypost/track/details/CD123456789AU",
      "H01ABC1234567890" => "https://www.evri.com/track/parcel/H01ABC1234567890/details",
      "15501234567890" => "https://track.dpd.co.uk/parcels/15501234567890"
    }.each do |code, url|
      assert_equal url, TrackingLink.for(code).url, "expected #{code} to link to its carrier"
    end
  end

  test "an unrecognised code is shown as plain text" do
    link = TrackingLink.for("ORD-12345")

    assert_nil link.url
    assert_equal "ORD-12345", link.to_slack_mrkdwn
  end

  test "slack mrkdwn links the label and escapes it" do
    assert_equal "<https://mail.hackclub.com/pkg!abc|pkg!abc>", TrackingLink.for("pkg!abc").to_slack_mrkdwn
    assert_equal "A&amp;B &lt;1&gt;", TrackingLink.for("A&B <1>").to_slack_mrkdwn
  end
end
