require 'spec_helper'


describe 'CloudYaml' do
  describe 'load_yaml' do
    subject { account.load_yaml }
    account_file = '.test.yml'
    before (:all) do
      accounts = {'onedrive' => {'login_account' => 'login@onedrive.com', 'login_password' => 'onedrive'}}
      open(account_file, 'wb') { |file| YAML.dump(accounts, file) }
    end
    context 'file & storage exists' do
      let(:account) { Fabricate.build(:cloud_yaml, :file => account_file) }
      it { expect(subject).to be_true }
    end
    context 'file not exists' do
      let(:account) { Fabricate.build(:cloud_yaml, :file => 'example.yml') }
      it { expect(subject).to be_false }
    end
    context 'storage exists' do
      let(:account) { Fabricate.build(:cloud_yaml, :file => account_file, :storage => 'example') }
      it { expect(subject).to be_false }
    end
    after (:all) do
      File.delete(account_file) if File.exists?(account_file)
    end
  end
end