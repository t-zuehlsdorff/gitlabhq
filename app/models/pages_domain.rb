class PagesDomain < ActiveRecord::Base
  belongs_to :project

  validates :domain, hostname: { allow_numeric_hostname: true }
  validates :domain, uniqueness: { case_sensitive: false }
  validates :certificate, certificate: true, allow_nil: true, allow_blank: true
  validates :key, certificate_key: true, allow_nil: true, allow_blank: true

  validate :validate_pages_domain
  validate :validate_matching_key, if: ->(domain) { domain.certificate.present? || domain.key.present? }
  validate :validate_intermediates, if: ->(domain) { domain.certificate.present? }

  attr_encrypted :key,
    mode: :per_attribute_iv_and_salt,
    insecure_mode: true,
    key: Gitlab::Application.secrets.db_key_base,
    algorithm: 'aes-256-cbc'

  after_create :update
  after_save :update
  after_destroy :update

  def to_param
    domain
  end

  def url
    return unless domain

    if certificate
      "https://#{domain}"
    else
      "http://#{domain}"
    end
  end

  def has_matching_key?
    return false unless x509
    return false unless pkey

    # We compare the public key stored in certificate with public key from certificate key
    x509.check_private_key(pkey)
  end

  def has_intermediates?
    return false unless x509

    # self-signed certificates doesn't have the certificate chain
    return true if x509.verify(x509.public_key)

    store = OpenSSL::X509::Store.new
    store.set_default_paths

    # This forces to load all intermediate certificates stored in `certificate`
    Tempfile.open('certificate_chain') do |f|
      f.write(certificate)
      f.flush
      store.add_file(f.path)
    end

    store.verify(x509)
  rescue OpenSSL::X509::StoreError
    false
  end

  def expired?
    return false unless x509
    current = Time.new
    current < x509.not_before || x509.not_after < current
  end

  def subject
    return unless x509
    x509.subject.to_s
  end

  def certificate_text
    @certificate_text ||= x509.try(:to_text)
  end

  private

  def update
    ::Projects::UpdatePagesConfigurationService.new(project).execute
  end

  def validate_matching_key
    unless has_matching_key?
      self.errors.add(:key, "doesn't match the certificate")
    end
  end

  def validate_intermediates
    unless has_intermediates?
      self.errors.add(:certificate, 'misses intermediates')
    end
  end

  def validate_pages_domain
    return unless domain
    if domain.downcase.ends_with?(Settings.pages.host.downcase)
      self.errors.add(:domain, "*.#{Settings.pages.host} is restricted")
    end
  end

  def x509
    return unless certificate
    @x509 ||= OpenSSL::X509::Certificate.new(certificate)
  rescue OpenSSL::X509::CertificateError
    nil
  end

  def pkey
    return unless key
    @pkey ||= OpenSSL::PKey::RSA.new(key)
  rescue OpenSSL::PKey::PKeyError, OpenSSL::Cipher::CipherError
    nil
  end
end
