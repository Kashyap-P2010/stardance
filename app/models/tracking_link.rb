# A shipment tracking code and where to follow it. Admins paste whatever the
# carrier gave them — a bare number, a full tracking URL, or a Hack Club mail
# id — and this is the one place that decides whether (and where) it links,
# so the admin order page, the user's order list and Slack DMs all agree.
class TrackingLink < Data.define(:code)
  HACK_CLUB_MAIL_PREFIXES = %w[pkg! ltr!].freeze

  # Matched against the code with spaces removed and upcased, since carriers
  # print long numbers in spaced groups ("9400 1000 ...").
  CARRIER_URLS = {
    /\A9[2-5]\d{18,24}\z/ => "https://tools.usps.com/go/TrackConfirmAction?tLabels=%s", # USPS
    /\A1Z[0-9A-Z]{16}\z/ => "https://www.ups.com/track?tracknum=%s", # UPS
    /\A[A-Z]{2}\d{9}GB\z/ => "https://www.royalmail.com/track-your-item#/tracking-results/%s", # Royal Mail
    /\A[A-Z]{2}\d{9}AU\z/ => "https://auspost.com.au/mypost/track/details/%s", # Australia Post
    /\AH[0-9A-Z]{15}\z/ => "https://www.evri.com/track/parcel/%s/details", # Evri
    /\A\d{14}\z/ => "https://track.dpd.co.uk/parcels/%s" # DPD
  }.freeze

  URL_LABEL = "Track your package".freeze

  def self.for(code)
    new(code: code.to_s.strip) if code.present?
  end

  def url
    return code if web_url?
    return "https://mail.hackclub.com/#{code}" if code.start_with?(*HACK_CLUB_MAIL_PREFIXES)

    normalized = code.delete(" ").upcase
    CARRIER_URLS.each { |pattern, template| return format(template, normalized) if pattern.match?(normalized) }
    nil
  end

  # A pasted URL is long and meaningless to read, so it gets a friendly label;
  # anything else is shown as the code itself.
  def label
    web_url? ? URL_LABEL : code
  end

  def to_slack_mrkdwn
    text = label.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    url ? "<#{url}|#{text}>" : text
  end

  private

  def web_url?
    uri = URI.parse(code)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end
end
