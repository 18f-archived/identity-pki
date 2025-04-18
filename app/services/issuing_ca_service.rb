class IssuingCaService
  CA_ISSUER_HOST_ALLOW_LIST = IdentityConfig.store.ca_issuer_host_allow_list

  class UnexpectedPKCS7Response < StandardError; end

  CA_RESPONSE_CACHE_EXPIRATION = 60.minutes

  def self.fetch_signing_key_for_cert(cert)
    ca_issuers = ca_issuers_for_cert(cert)
    ca_issuers.each do |ca_issuer_uri|
      next unless allowed_host?(ca_issuer_uri.host)
      signing_cert = fetch_issuing_certificate(ca_issuer_uri, cert.signing_key_id)
      return signing_cert if signing_cert.present?
    end

    nil
  end

  def self.fetch_issuing_certificate(ca_issuer_uri, signing_key_id)
    @ca_certificates_response_cache ||= MiniCache::Store.new
    key = [ca_issuer_uri.to_s, signing_key_id].inspect

    cached_result = @ca_certificates_response_cache.get(key)
    return cached_result if @ca_certificates_response_cache.set?(key)

    ca_x509_certificates = fetch_certificates(ca_issuer_uri)

    ca_x509_certificates.each do |ca_x509_certificate|
      ca_certificate = Certificate.new(ca_x509_certificate)
      if signing_key_id == ca_certificate.key_id
        return @ca_certificates_response_cache.set(key, ca_certificate, expires_in: CA_RESPONSE_CACHE_EXPIRATION)
      end
    end

    @ca_certificates_response_cache.set(key, nil, expires_in: CA_RESPONSE_CACHE_EXPIRATION)
  end

  def self.ca_issuers_for_cert(cert)
    return [] if cert.aia.blank? || !cert.aia['CA Issuers'].is_a?(Array)

    cert.aia['CA Issuers'].map do |issuer|
      convert_uri(issuer)
    end.compact
  end

  def self.fetch_ca_repository_certs_for_cert(cert)
    return [] if cert.subject_info_access.blank? || !cert.subject_info_access['CA Repository'].is_a?(Array)

    repository_uris = cert.subject_info_access['CA Repository'].map do |repo|
      convert_uri(repo)
    end.compact

    repository_uris.map do |repository_uri|
      IssuingCaService.fetch_certificates(repository_uri).map do |x509_cert|
        Certificate.new(x509_cert)
      end
    end.flatten
  end

  def self.clear_ca_certificates_response_cache!
    @ca_certificates_response_cache&.reset
  end

  def self.fetch_certificates(issuer_uri)
    http = Net::HTTP.new(issuer_uri.hostname, issuer_uri.port)
    response = http.get(issuer_uri.path)
    if response.kind_of?(Net::HTTPSuccess)
      OpenSSL::PKCS7.new(response.body).certificates || []
    else
      NewRelic::Agent.notice_error(
        UnexpectedPKCS7Response.new(response.body),
        custom_params: { issuer_uri: issuer_uri.to_s },
      )

      []
    end
  rescue OpenSSL::PKCS7::PKCS7Error,
         ArgumentError,
         Errno::ECONNREFUSED,
         Net::ReadTimeout,
         Net::OpenTimeout => error

    NewRelic::Agent.notice_error(
      error,
      custom_params: { issuer_uri: issuer_uri.to_s, response_body: response&.body },
    )
    begin
      if response.present?
        [OpenSSL::X509::Certificate.new(response&.body)]
      else
        []
      end
    rescue OpenSSL::X509::CertificateError,
           ArgumentError
      []
    end
  end

  def self.ca_issuer_host_allow_list
    CA_ISSUER_HOST_ALLOW_LIST
  end

  def self.allowed_host?(host)
    return true if ca_issuer_host_allow_list.include?(host)

    Rails.logger.info("CA Issuer Host Not Allowed: #{host}")
    false
  end

  def self.certificate_store_issuers
    CertificateStore.instance.certificates.map do |certificate|
      ca_issuers_for_cert(certificate)
    end.flatten.uniq
  end

  def self.convert_uri(uri)
    uri = uri.to_s
    return nil unless uri.starts_with?('URI')
    uri = uri.gsub(/^URI:/, '')
    uri = URI.parse(uri)
    return nil unless uri.scheme == 'http'
    uri
  end

  # Recursively find all certificates issued
  def self.find_all_issued_certificates(cert, certs: {})
    certs[cert.key_id] = cert

    certificates = fetch_ca_repository_certs_for_cert(cert).compact
    certificates.each do |certificate|
      next if certs[certificate.key_id]
      certs[certificate.key_id] = certificate

      find_all_issued_certificates(certificate, certs: certs)
    end

    certs
  end
end
