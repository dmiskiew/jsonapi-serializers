describe JSONAPI::ErrorSerializer do
  def serialize_primary(object, options = {})
    # Note: intentional high-coupling to protected method for tests.
    JSONAPI::ErrorSerializer.send(:serialize_primary, object, options)
  end

  describe 'internal-only serialize_primary' do
    it 'can serialize primary data for a simple error object' do
      error = create(:error)
      primary_data = serialize_primary(error, {serializer: MyApp::SimplestErrorSerializer})
      expect(primary_data).to eq({
        'title' => 'Error message 1',
        'detail' => 'Error details',
        'status' => 422
      })
    end
  end

  describe 'JSONAPI::ErrorSerializer.serialize' do
    # The following tests rely on the fact that serialize_primary has been tested above, so object
    # primary data is not explicitly tested here. If things are broken, look above here first.

    it 'can serialize a simple object' do
      error = create(:error)
      expect(JSONAPI::ErrorSerializer.serialize(error)).to eq({
        'errors' => [serialize_primary(error, {serializer: MyApp::StandardErrorSerializer})],
      })
    end
  end
end
