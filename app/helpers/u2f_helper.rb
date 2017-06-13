module U2fHelper
  def inject_u2f_api?
    ((browser.chrome? && browser.version.to_i >= 41) || (browser.opera? && browser.version.to_i >= 40)) && !browser.device.mobile?
  end
end
