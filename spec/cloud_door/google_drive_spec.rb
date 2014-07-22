require 'spec_helper'

describe 'GoogleDrive' do
  let(:storage) do
    storage = create_storage(CloudDoor::GoogleDrive)
    storage.token.credentials = Marshal.dump('credentials')
    token_file = storage.token.token_file
    Google::APIClient.any_instance.stub(:authorization=)
      .and_return(true)
    Google::APIClient.any_instance.stub(:discovered_api)
      .and_return(true)
    CloudDoor::GoogleDriveBridge.any_instance.stub(:request_root_id)
      .and_return('top')
    open(token_file, 'wb') { |file| file << Marshal.dump(storage.token) }
    storage.load_token
    storage
  end

  describe 'reset_token' do
    subject { storage.reset_token(token_value) }
    let(:storage) { create_storage(CloudDoor::GoogleDrive) }
    let(:token_value) { {'credentials' => 'credentials'} }
    context 'success' do
      it do
        subject
        expect(storage.token.credentials).to eq 'credentials'
      end
    end
    context 'fail' do
      context 'not Token class' do
        before(:each) do
          storage.token = 'token'
        end
        it { expect { subject }.to raise_error(CloudDoor::TokenClassException) }
      end
    end
  end

  describe 'show_user' do
    subject { storage.show_user }
    let(:token_file) { storage.token.token_file }
    context 'success' do
      let(:posit) { {'name' => 'google'} }
      it do
        expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_user)
          .and_return(posit)
        is_expected.to eq posit
      end
    end
    after(:each) do
      File.delete(token_file) if File.exist?(token_file)
    end
  end

  describe 'show_files' do
    subject { storage.show_files(file_name) }
    let(:list_file) { storage.file_list.list_file }
    let(:token_file) { storage.token.token_file }
    context 'success' do
      let(:file_name) { nil }
      context 'data exists' do
        let(:posit) do
          [
            {'id' => 'file1234', 'title' => 'file1', 'mimeType' => 'text/plain'},
            {'id' => 'folder1234', 'title' => 'folder1', 'mimeType' => 'application/vnd.google-apps.folder'},
          ]
        end
        let(:result) do
          {
            'file1'   => {'id' => 'file1234', 'type' => 'file'},
            'folder1' => {'id' => 'folder1234', 'type' => 'folder'}
          }
        end
        it do
          expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_dir)
            .with('top')
            .and_return(posit)
          is_expected.to eq result
        end
      end
      context 'data not exists' do
        let(:posit) { [] }
        it do
          expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_dir)
            .and_return(posit)
          is_expected.to eq({})
        end
      end
    end
    context 'fail' do
      let(:file_name) { 'file9' }
      context 'file id not exits' do
        it { expect { subject }.to raise_error(CloudDoor::SetIDException) }
      end
      context 'not directory' do
        before(:each) do
          list  = [{'items' => {'file9' => {'id' => 'file9876', 'type' => 'file'}}}]
          open(list_file, 'wb') { |file| file << Marshal.dump(list) }
        end
        it { expect { subject }.to raise_error(CloudDoor::NotDirectoryException) }
      end
    end
    after(:each) do
      File.delete(list_file) if File.exist?(list_file)
      File.delete(token_file) if File.exist?(token_file)
    end
  end

  describe 'change_directory' do
    subject { storage.change_directory(file_name) }
    let(:list_file) { storage.file_list.list_file }
    let(:token_file) { storage.token.token_file }
    context 'success' do
      let(:file_name) { 'folder1' }
      before(:each) do
        list  = [{'items' => {'folder1' => {'id' => 'folder1234', 'type' => 'folder'}}}]
        open(list_file, 'wb') { |file| file << Marshal.dump(list) }
      end
      context 'data exists' do
        let(:posit) do
          [
            {'id' => 'file1234', 'title' => 'file1', 'mimeType' => 'text/plain'},
            {'id' => 'folder1234', 'title' => 'folder1', 'mimeType' => 'application/vnd.google-apps.folder'},
          ]
        end
        let(:result) do
          {
            'file1'   => {'id' => 'file1234', 'type' => 'file'},
            'folder1' => {'id' => 'folder1234', 'type' => 'folder'}
          }
        end
        it do
          expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_dir)
            .with('folder1234')
            .and_return(posit)
          is_expected.to eq result
        end
      end
      context 'data not exists' do
        let(:posit) { [] }
        it do
          expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_dir)
            .with('folder1234')
            .and_return(posit)
          is_expected.to eq({})
        end
      end
    end
    context 'fail' do
      context 'file name not input' do
        let(:file_name) { '' }
        it { expect { subject }.to raise_error(CloudDoor::FileNameEmptyException) }
      end
      context 'file id not exits' do
        let(:file_name) { 'file9' }
        it { expect { subject }.to raise_error(CloudDoor::SetIDException) }
      end
      context 'not directory' do
        let(:file_name) { 'file9' }
        before(:each) do
          list  = [{'items' => {'file9' => {'id' => '/file9', 'type' => 'file'}}}]
          open(list_file, 'wb') { |file| file << Marshal.dump(list) }
        end
        it { expect { subject }.to raise_error(CloudDoor::NotDirectoryException) }
      end
    end
    after(:each) do
      File.delete(list_file) if File.exist?(list_file)
      File.delete(token_file) if File.exist?(token_file)
    end
  end

  describe 'show_current_directory' do
    subject { storage.show_current_directory }
    let(:storage) { create_storage(CloudDoor::GoogleDrive) }
    it { is_expected.to eq('/top') }
  end

  describe 'show_property' do
    subject { storage.show_property(file_name) }
    let(:list_file) { storage.file_list.list_file }
    let(:token_file) { storage.token.token_file }
    before(:each) do
      list = [{'items' => {'file1' => {'id' => 'file1234', 'type' => 'file'}}}]
      open(list_file, 'wb') { |file| file << Marshal.dump(list) }
    end
    context 'success' do
      context 'file exists' do
        let(:file_name) { 'file1' }
        let(:posit) do
          {
            'name'         => 'file1',
            'bytes'        => 38,
            'modified'     => '2014-06-01 12:20:30',
            'client_mtime' => '2014-06-05 13:30:40',
            'path'         => 'file1234',
            'is_dir'       => false
          }
        end
        before(:each) do
          storage.stub(:file_exist?)
            .with(file_name)
            .and_return(true)
        end
        it do
          expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_file)
            .with('file1234')
            .and_return(posit)
          is_expected.to eq posit
        end
      end
    end
    context 'fail' do
      context 'file name not input' do
        let(:file_name) { '' }
        it { expect { subject }.to raise_error(CloudDoor::FileNameEmptyException) }
      end
      context 'file id not exits' do
        let(:file_name) { 'test' }
        it { expect { subject }.to raise_error(CloudDoor::SetIDException) }
      end
      context 'file not exits on cloud' do
        let(:file_name) { 'file1' }
        before(:each) do
          storage.stub(:file_exist?)
            .with(file_name)
            .and_return(false)
        end
        it { expect { subject }.to raise_error(CloudDoor::FileNotExistsException) }
      end
      context 'no data' do
        let(:file_name) { 'file1' }
        let(:posit) { nil }
        before(:each) do
          storage.stub(:file_exist?)
            .with(file_name)
            .and_return(true)
          CloudDoor::GoogleDriveBridge.any_instance.stub(:request_file)
            .and_return(posit)
        end
        it { expect { subject }.to raise_error(CloudDoor::NoDataException) }
      end
    end
    after(:each) do
      File.delete(list_file) if File.exist?(list_file)
      File.delete(token_file) if File.exist?(token_file)
    end
  end

=begin
  describe 'pick_cloud_info' do
    subject { storage.pick_cloud_info(method, key) }
    let(:storage) { create_storage(CloudDoor::GoogleDrive) }
    context 'user' do
      let(:method) { 'request_user' }
      let(:key) { 'name' }
      let(:posit) { {'name' => 'dropbox'} }
      it do
        expect_any_instance_of(GoogleDriveClient).to receive(:account_info)
          .and_return(posit)
        is_expected.to eq 'dropbox'
      end
    end
    context 'dir' do
      let(:method) { 'request_dir' }
      let(:key) { 'contents' }
      let(:posit) { {'contents' => ['file1']} }
      it do
        expect_any_instance_of(GoogleDriveClient).to receive(:metadata)
          .with(CloudDoor::GoogleDrive::ROOT_ID)
          .and_return(posit)
        is_expected.to eq ['file1']
      end
    end
    context 'file' do
      let(:storage) { create_storage(CloudDoor::GoogleDrive, '/file1') }
      let(:method) { 'request_file' }
      let(:key) { 'name' }
      let(:posit) { {'path' => '/file1', 'name' => 'file1', 'is_dir' => false} }
      it do
        expect_any_instance_of(GoogleDriveClient).to receive(:metadata)
          .with(storage.file_id)
          .and_return(posit)
        is_expected.to eq 'file1'
      end
    end
    context 'fail' do
      let(:method) { 'request_user' }
      let(:key) { 'name' }
      let(:posit) { {'name' => 'onedrive'} }
      before(:each) do
        GoogleDriveClient.any_instance.stub(:account_info)
          .and_return(posit)
      end
      context 'method not exists' do
        let(:method) { 'request_member' }
        it { expect { subject }.to raise_error(CloudDoor::RequestMethodNotFoundException) }
      end
      context 'data not exists' do
        let(:posit) { nil }
        it { expect { subject }.to raise_error(CloudDoor::NoDataException) }
      end
      context 'key not exists' do
        let(:key) { 'firstname' }
        it { expect { subject }.to raise_error(CloudDoor::RequestPropertyNotFoundException) }
      end
    end
  end
=end

  describe 'download_file' do
    subject { storage.download_file(file_name) }
    let(:list_file) { storage.file_list.list_file }
    let(:token_file) { storage.token.token_file }
    context 'success' do
      let(:file_name) { 'file1' }
      let(:posit) { ['test', {'path' => 'test', 'name' => 'test'}] }
      before(:each) do
        list = [{'items' => {'file1' => {'id' => 'file1234', 'type' => 'file'}}}]
        open(list_file, 'wb') { |file| file << Marshal.dump(list) }
      end
      it do
        expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_download)
          .with('file1234')
          .and_return(posit)
        is_expected.to be_truthy
      end
      after(:each) do
        File.delete('file1') if File.exist?('file1')
      end
    end
    context 'fail' do
      context 'file name not input' do
        let(:file_name) { '' }
        it { expect { subject }.to raise_error(CloudDoor::FileNameEmptyException) }
      end
      context 'file id not exits' do
        let(:file_name) { 'test' }
        it { expect { subject }.to raise_error(CloudDoor::SetIDException) }
      end
      context 'not file' do
        let(:file_name) { 'folder1' }
        before(:each) do
          list = [{'items' => {'folder1' => {'id' => '/folder1', 'type' => 'folder'}}}]
          open(list_file, 'wb') { |file| file << Marshal.dump(list) }
        end
        it { expect { subject }.to raise_error(CloudDoor::NotFileException) }
      end
    end
    after(:each) do
      File.delete(list_file) if File.exist?(list_file)
      File.delete(token_file) if File.exist?(token_file)
    end
  end

  describe 'upload_file' do
    subject { storage.upload_file(file_name) }
    let(:list_file) { storage.file_list.list_file }
    let(:up_file) { 'upload' }
    let(:token_file) { storage.token.token_file }
    context 'success' do
      let(:file_name) { up_file }
      let(:posit_dir) do
        [{'id' => 'file1234', 'title' => 'file1', 'mimeType' => 'text/plain'}]
      end
      before(:each) do
        open(up_file, 'wb') { |file| file << 'upload' }
      end
      it do
        expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_upload)
          .and_return(true)
        expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_dir)
          .with('top')
          .and_return(posit_dir)
        is_expected.to be_truthy
      end
    end
    context 'fail' do
      context 'upload file name not input' do
        let(:file_name) { '' }
        it { expect { subject }.to raise_error(CloudDoor::FileNameEmptyException) }
      end
      context 'file not exits' do
        let(:file_name) { up_file }
        it { expect { subject }.to raise_error(CloudDoor::FileNotExistsException) }
      end
    end
    after(:each) do
      File.delete(up_file) if File.exist?(up_file)
      File.delete(list_file) if File.exist?(list_file)
      File.delete(token_file) if File.exist?(token_file)
    end
  end

  describe 'delete_file' do
    subject { storage.delete_file(file_name) }
    let(:list_file) { storage.file_list.list_file }
    let(:token_file) { storage.token.token_file }
    context 'success' do
      let(:file_name) { 'file1' }
      let(:posit_dir) do
        [{'id' => 'file1234', 'title' => 'file1', 'mimeType' => 'text/plain'}]
      end
      before(:each) do
        list = [{'items' => {'file1' => {'id' => 'file1234', 'type' => 'file'}}}]
        open(list_file, 'wb') { |file| file << Marshal.dump(list) }
      end
      it do
        expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_delete)
          .with('file1234')
          .and_return(true)
        expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_dir)
          .with('top')
          .and_return(posit_dir)
        is_expected.to be_truthy
      end
    end
    context 'fail' do
      context 'file name not input' do
        let(:file_name) { '' }
        it { expect { subject }.to raise_error(CloudDoor::FileNameEmptyException) }
      end
      context 'file id not exits' do
        let(:file_name) { 'test' }
        it { expect { subject }.to raise_error(CloudDoor::SetIDException) }
      end
    end
    after(:each) do
      File.delete(list_file) if File.exist?(list_file)
      File.delete(token_file) if File.exist?(token_file)
    end
  end

  describe 'make_directory' do
    subject { storage.make_directory(mkdir_name) }
    let(:list_file) { storage.file_list.list_file }
    let(:token_file) { storage.token.token_file }
    context 'success' do
      let(:mkdir_name) { 'folder1' }
      let(:posit_dir) do
        [{'id' => 'file1234', 'title' => 'file1', 'mimeType' => 'text/plain'}]
      end
      it do
        expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_mkdir)
          .with('folder1', 'top')
          .and_return(true)
        expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_dir)
          .with('top')
          .and_return(posit_dir)
        is_expected.to be_truthy
      end
    end
    context 'fail' do
      context 'file name not input' do
        let(:mkdir_name) { '' }
        it { expect { subject }.to raise_error(CloudDoor::DirectoryNameEmptyException) }
      end
    end
    after(:each) do
      File.delete(list_file) if File.exist?(list_file)
      File.delete(token_file) if File.exist?(token_file)
    end
  end

  describe 'assign_upload_file_name' do
    subject { storage.assign_upload_file_name(file_name) }
    let(:storage) { create_storage(CloudDoor::GoogleDrive) }
    context 'file' do
      let(:file_name) { 'testfile' }
      it { is_expected.to eq file_name }
    end
    context 'directory' do
      let(:file_name) { 'testdir' }
      before(:each) do
        Dir.mkdir(file_name)
      end
      it { is_expected.to eq "#{file_name}.zip" }
      after(:each) do
        Dir.rmdir(file_name) if File.exist?(file_name)
      end
    end
  end

  describe 'file_exist?' do
    subject { storage.file_exist?(file_name) }
    let(:list_file) { storage.file_list.list_file }
    let(:token_file) { storage.token.token_file }
    before(:each) do
      list = [{'items' => {'file1' => {'id' => 'file1234', 'type' => 'file'}}}]
      open(list_file, 'wb') { |file| file << Marshal.dump(list) }
    end
    context 'return true' do
      let(:posit) do
        [{'id' => 'file1234', 'title' => 'file1', 'mimeType' => 'text/plain'}]
      end
      context 'file exists' do
        let(:file_name) { 'file1' }
        it do
          expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_dir)
            .with('top')
            .and_return(posit)
          is_expected.to be_truthy
        end
      end
    end
    context 'return false' do
      let(:posit) do
        [{'id' => 'file5678', 'title' => 'file2', 'mimeType' => 'text/plain'}]
      end
      context 'file not found' do
        let(:file_name) { 'file1' }
        before(:each) do
          CloudDoor::GoogleDriveBridge.any_instance.stub(:request_dir)
            .and_return(posit)
        end
        it { is_expected.to be_falsey }
      end
    end
    after(:each) do
      File.delete(list_file) if File.exist?(list_file)
    end
  end

  describe 'has_file?' do
    subject { storage.has_file?(file_name) }
    let(:list_file) { storage.file_list.list_file }
    let(:token_file) { storage.token.token_file }
    before(:each) do
      file1   = {'id' => 'file1234', 'type' => 'file'}
      folder1 = {'id' => 'folder1234', 'type' => 'folder'}
      list = [
        {'items' => {'file1' => file1, 'folder1' => folder1}}
      ]
      open(list_file, 'wb') { |file| file << Marshal.dump(list) }
    end
    context 'return true' do
      context 'count > 0' do
        let(:file_name) { 'folder1' }
        let(:posit) do
          [
            {'id' => 'file1234', 'title' => 'file1', 'mimeType' => 'text/plain'},
            {'id' => 'file5678', 'title' => 'file2', 'mimeType' => 'text/plain'}
          ]
        end
        before(:each) do
          storage.stub(:file_exist?)
            .with(file_name)
            .and_return(true)
        end
        it do
          expect_any_instance_of(CloudDoor::GoogleDriveBridge).to receive(:request_dir)
            .with('folder1234')
            .and_return(posit)
          is_expected.to be_truthy
        end
      end
    end
    context 'return false' do
      context 'target is file' do
        let(:file_name) { 'file1' }
        it { is_expected.to be_falsey }
      end
      context 'count == 0' do
        let(:file_name) { 'folder1' }
        let(:posit) { [] }
        before(:each) do
          storage.stub(:file_exist?)
            .with(file_name)
            .and_return(true)
          CloudDoor::GoogleDriveBridge.any_instance.stub(:request_dir).and_return(posit)
        end
        it { is_expected.to be_falsey }
      end
    end
    context 'fail' do
      context 'file name not input' do
        let(:file_name) { '' }
        it { expect { subject }.to raise_error(CloudDoor::FileNameEmptyException) }
      end
      context 'file id not exits' do
        let(:file_name) { 'test' }
        it { expect { subject }.to raise_error(CloudDoor::SetIDException) }
      end
    end
    after(:each) do
      File.delete(list_file) if File.exist?(list_file)
      File.delete(token_file) if File.exist?(token_file)
    end
  end

  describe 'file?' do
    subject { storage.file?(file_name) }
    let(:storage) { create_storage(CloudDoor::GoogleDrive) }
    let(:list_file) { storage.file_list.list_file }
    before(:each) do
      file1   = {'id' => 'file1234', 'name' => 'file1', 'type' => 'file'}
      folder1 = {'id' => 'folder1234', 'name' => 'folder1', 'type' => 'folder'}
      list = [
        {'items' => {'file1' => file1, 'folder1' => folder1}}
      ]
      open(list_file, 'wb') { |file| file << Marshal.dump(list) }
    end
    context 'return true' do
      context 'file' do
        let(:file_name) { 'file1' }
        it { is_expected.to be_truthy }
      end
    end
    context 'return false' do
      context 'file name not input' do
        let(:file_name) { '' }
        it { is_expected.to be_falsey }
      end
      context 'parent' do
        let(:file_name) { '../' }
        it { is_expected.to be_falsey }
      end
      context 'folder' do
        let(:file_name) { 'folder1' }
        it { is_expected.to be_falsey }
      end
    end
  end

  describe 'load_token' do
    let(:storage) do
      storage = create_storage(CloudDoor::GoogleDrive)
      storage.token.credentials = Marshal.dump('credentials')
      token_file = storage.token.token_file
      Google::APIClient.any_instance.stub(:authorization=)
        .and_return(true)
      Google::APIClient.any_instance.stub(:discovered_api)
        .and_return(true)
      CloudDoor::GoogleDriveBridge.any_instance.stub(:request_root_id)
        .and_return('top')
      open(token_file, 'wb') { |file| file << Marshal.dump(storage.token) }
      storage
    end
    let(:token_file) { storage.token.token_file }
    it do
      result = storage.load_token
      expect(result.is_a?(CloudDoor::Token)).to be_truthy
    end
    after(:each) do
      File.delete(token_file) if File.exist?(token_file)
    end
  end
end
