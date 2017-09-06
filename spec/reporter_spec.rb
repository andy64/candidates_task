require_relative 'spec_helper'
require_relative '../lib/reporter'
require_relative '../lib/remote_connector'

describe 'Reporter' do
  before(:each) do
    @result_failed = {success: [1,2,3], :errors => ['4: Runtime error', '5: Not found']}
    @result_passed = {success: [1,2,3], :errors => []}
    @result_empty = {success: [], :errors => []}
    @csv_file = 'spec/fixtures/csv_empty.csv'
  end

  describe '.upload_error_file' do
    it 'form and upload error file' do
      reporter = Reporter.new(@csv_file, @result_failed, true )
      tmpdir = 'temp'
      FileUtils.rm_rf tmpdir
      FileUtils.mkpath tmpdir
      filename = 'errors.txt'
      allow(reporter).to receive(:local_data_upload_path).and_return tmpdir+'/'
      allow_any_instance_of(RemoteConnector).to receive(:upload_file).and_return true
      content = ['some errors']
      reporter.send(:upload_error_file, filename, content)
      File.exist?(tmpdir).should be true
      entries = Dir.entries(tmpdir).reject { |x| x=='.' or x=='..' }
      entries.size.should == 1
      entries.each do |file|
        rez = File.readlines(tmpdir+'/'+file)
        rez.last.should == "[\"some errors\"]"
        rez.size.should == 1
      end
      FileUtils.rm_rf tmpdir
    end
  end

describe '.report_results' do
  it 'process the successful file import results with email sending' do
    tmpdir = 'temp'
    FileUtils.mkpath tmpdir
    filepath = "#{tmpdir}/#{File.basename(@csv_file)}"
    FileUtils.copy @csv_file, filepath
    stub_const('BackendMailer', Class.new)
    BackendMailer.stub(:send_import_feedback)
    reporter = Reporter.new(filepath, @result_passed, true)
    BackendMailer.should receive(:send_import_feedback).once.with('Successful Import', 'Import of the file \'csv_empty.csv\' is done.')
    reporter.should receive(:successful_import).once.and_call_original
    reporter.should receive(:rails_log).once
    reporter.report_results
    File.exist?(filepath).should be false
    FileUtils.rm_rf tmpdir
  end

  it 'process results of file import with errors with email sending' do
    stub_const('BackendMailer', Class.new)
    BackendMailer.stub(:send_import_feedback)
    reporter = Reporter.new(@csv_file, @result_failed, true)
    BackendMailer.should receive(:send_import_feedback).once.with('Import CSV failed', instance_of(Array))
    reporter.should_not receive(:successful_import)
    reporter.should receive(:upload_error_file).once
    reporter.should receive(:failed_import).once.and_call_original
    reporter.should receive(:rails_log).once
    reporter.report_results
  end
end


end

