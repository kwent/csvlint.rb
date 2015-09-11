require 'spec_helper'

describe Csvlint::StreamingValidator do

  # before do
  #   stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :body => "")
  # end

  context "tests to compare CSV native methods" do

    it "validates correctly using cascade" do
      stream = ["\"a\",\"b\",\"c\"\r\n"]
      validator = Csvlint::StreamingValidator.new(stream)
      validator.validate
      expect(validator.valid?).to eql(true)
    end

    it "uses CSV parse" do
      stream = ["\"a\",\"b\",\"c\"\r\n"]
      validator = Csvlint::StreamingValidator.new(stream)
      validator.validate
      # validator.parse_content(stream)
      expect(validator.valid?).to eql(true)
    end

    it "uses CSV parse and StringIO" do
      data = ["1,2,3\r\n"]
      validator = Csvlint::StreamingValidator.new(data)
      validator.validate
      # validator.parse_content(data)
      expect( validator.valid? ).to eql(true)
    end

  end

  context "content validation should pass without passing stream to initialise" do

    it "passes a compliant string with no errors" do
      # data = StringIO.new( "1,2,3\r\n" )
      data = ["1,2,3\r\n"]
      validator = Csvlint::StreamingValidator.new()
      # validator.validate
      validator.parse_contents(data)
      expect( validator.valid? ).to eql(true)
      expect(validator.info_messages.size).to eql(0) # presuming assumed header message will generate
    end

    it "parses CSV and catches whitespace" do
      # data = StringIO.new("\"\",\"\",\"\\")
      data = ["\"\",\"\",\"\\"]
      validator = Csvlint::StreamingValidator.new(data)
      # validator.validate
      validator.parse_contents(data)
      expect(validator.valid?).to eql(false)
      expect(validator.errors.first.type).to eql(:whitespace)
    end
  end

  context "validation with multiple lines " do
    it "parses CSV when provided with an init and input" do
      # data = StringIO.new("\"Foo\",\"Bar\",\"Baz\"\r\n\"1\",\"2\",\"3\"\r\n\"1\",\"2\",\"3\"\r\n\"3\",\"2\",\"1\"")
      data = [["\"Foo\",\"Bar\",\"Baz\"\r\n"], ["1\",\"2\",\"3\"\r\n"], ["1\",\"2\",\"3\"\r\n"], ["3\",\"2\",\"1\""]]

      # binding.pry
      validator = Csvlint::StreamingValidator.new(data)
      # validator.validate
      data.each do |d|
        validator.parse_contents(d)
      end
      # validator.parse_contents(data)
      expect(validator.valid?).to eql(true)
    end

    it "parses CSV and catches whitespace" do
      # data = StringIO.new(" \"Foo\",\"Bar\",\"Baz\"\r\n\"1\",\"2\",\"3\"\r\n\"1\",\"2\",\"3\"\r\n\"3\",\"2\",\"1\" ")
      data = [["\"Foo\",\"Bar\",\"   Baz\"\r\n"], ["1\",\"2\",\"3\"\r\n"], ["1\",\"2\",\"3\"\r\n"], ["3\",\"2\",\"1\""]]
      validator = Csvlint::StreamingValidator.new(data)
      data.each do |d|
        validator.parse_contents(d)
      end
      # validator.validate
      expect(validator.valid?).to eql(false)
      expect(validator.errors.first.type).to eql(:whitespace)
    end
  end

  context "with a single row" do

    it "validates correctly" do
      stream = ["\"a\",\"b\",\"c\"\r\n"]
      validator = Csvlint::StreamingValidator.new(stream)
      validator.validate
      expect(validator.valid?).to eql(true)
    end

    it "checks for non rfc line breaks" do
      # this test implies knowledge of CSV.row_sep, a value that can only be obtained by CSV.new()
      # CSV.new() doesn't read the entire file into memory but it does create another object in memory
      stream = ["\"a\",\"b\",\"c\"\n"]
      csv = CSV.instance(stream)
      validator = Csvlint::StreamingValidator.new(stream, nil, nil, {}, csv.row_sep)
      validator.report_line_breaks(csv.row_sep)
      # validator.validate
      validator.parse_contents(stream)
      expect(validator.valid?).to eql(true)
      expect(validator.info_messages.count).to eq(2)
      expect(validator.info_messages.first.type).to eql(:nonrfc_line_breaks)
    end

    it "checks for blank rows" do
      stream = ["\"\",\"\",\"\"\r\n"]
      # stream = [""","""",""""\r\n"] TODO array processing doesn't seem to catch blank_rows anymore
      validator = Csvlint::StreamingValidator.new(stream)
      validator.parse_contents(stream)

      expect(validator.valid?).to eql(false)
      expect(validator.errors.count).to eq(1)
      expect(validator.errors.first.type).to eql(:blank_rows)
    end

    it "returns the content of the string with the error" do # TODO this fails because of how to_s rewrites the input
      # validator = Csvlint::StreamingValidator.new("\"\",\"\",\"\"\r\n")
      # validator.validate
      # binding.pry
      stream = ["\"\",\"\",\"\"\r\n"]
      validator = Csvlint::StreamingValidator.new(stream)
      validator.validate
      # validator.parse_content(stream)
      # validator.parse_cells(["\"\",\"\",\"\"\r\n"])
      # binding.pry
      expect(validator.errors.first.content).to eql("\"\",\"\",\"\"\r\n")
    end


    it "should handle stringIO input" do

      # data = StringIO.new( "1,2,3\r\n" )
      data = ["1,2,3\r\n"]
      validator = Csvlint::StreamingValidator.new(data)
      validator.validate
      expect( validator.valid? ).to eql(true)
      expect( validator.info_messages.size ).to eql(1)
      expect( validator.info_messages.first.type).to eql(:assumed_header)
      expect( validator.info_messages.first.category).to eql(:structure)

    end

    it "should presume a header unless told otherwise" do

      stream = ["1,2,3\r\n"]
      validator = Csvlint::StreamingValidator.new(stream)
      validator.validate

      expect( validator.valid? ).to eql(true)
      expect( validator.info_messages.size ).to eql(1)
      expect( validator.info_messages.first.type).to eql(:assumed_header)
      expect( validator.info_messages.first.category).to eql(:structure)
    end

  end

  context "it returns the correct error from ERROR_MATCHES" do
    # the ERROR_MATCHES messages are only built in response to CSV::Malformed Exceptions, so they cannot be invoked
    # separately to the validator.validate

    it "checks for unclosed quotes" do # TODO this is failing because of a rescue being misplaced
      stream = ["\"a,\"b\",\"c\"\n"]
      validator = Csvlint::StreamingValidator.new(stream)
      validator.validate # implicitly invokes parse_contents(stream)
      # validator.parse_contents(stream)
      expect(validator.valid?).to eql(false)
      expect(validator.errors.count).to eq(1)
      expect(validator.errors.first.type).to eql(:unclosed_quote)
    end

    it "checks for stray quotes" do
      stream = ["\"a\",“b“,\"c\"" "\r\n"]
      validator = Csvlint::StreamingValidator.new(stream)
      validator.validate # implicitly invokes parse_contents(stream)
      expect(validator.valid?).to eql(false)
      expect(validator.errors.count).to eq(1)
      expect(validator.errors.first.type).to eql(:stray_quote)
    end

    it "checks for whitespace" do
      # note that whitespace only catches prefacing and trailing whitespace as an error
      stream = [" \"a\",\"b\",\"c\"\r\n "]
      validator = Csvlint::StreamingValidator.new(stream) # implicitly invokes parse_contents(stream)
      validator.validate # implicitly invokes parse_contents(stream)
      expect(validator.valid?).to eql(false)
      expect(validator.errors.count).to eq(1)
      expect(validator.errors.first.type).to eql(:whitespace)
    end

    it "returns line break errors if incorrectly specified" do
      stream = ["\"a\",\"b\",\"c\"\n"]
      validator = Csvlint::StreamingValidator.new(stream, {"lineTerminator" => "\r\n"})
      validator.validate # implicitly invokes parse_contents(stream)
      expect(validator.valid?).to eql(false)
      expect(validator.errors.count).to eq(1)
      expect(validator.errors.first.type).to eql(:line_breaks)
    end

  end

  context "when validating headers" do

    it "should warn if column names aren't unique" do
      data = StringIO.new( "minimum, minimum" )
      validator = Csvlint::StreamingValidator.new(data)
      expect( validator.validate_header(["minimum", "minimum"]) ).to eql(true)
      expect( validator.warnings.size ).to eql(1)
      expect( validator.warnings.first.type).to eql(:duplicate_column_name)
      expect( validator.warnings.first.category).to eql(:schema)
    end

    it "should warn if column names are blank" do
      data = StringIO.new( "minimum," )
      validator = Csvlint::StreamingValidator.new(data)

      expect( validator.validate_header(["minimum", ""]) ).to eql(true)
      expect( validator.warnings.size ).to eql(1)
      expect( validator.warnings.first.type).to eql(:empty_column_name)
      expect( validator.warnings.first.category).to eql(:schema)
    end

    it "should include info message about missing header when we have assumed a header" do
      data = StringIO.new( "1,2,3\r\n" )
      validator = Csvlint::StreamingValidator.new(data)
      validator.validate_metadata(data) # data is equivalent to validator.stream
      expect( validator.valid? ).to eql(true)
      expect( validator.info_messages.size ).to eql(1)
      expect( validator.info_messages.first.type).to eql(:assumed_header)
      expect( validator.info_messages.first.category).to eql(:structure)
    end

    it "should not include info message about missing header when we are told about the header" do
      data = StringIO.new( "1,2,3\r\n" )
      validator = Csvlint::StreamingValidator.new(data, "header"=>false)

      expect( validator.valid? ).to eql(true)
      expect( validator.info_messages.size ).to eql(0)
    end
  end

  # context "build_formats" do
  #
  #   {
  #     :string => "foo",
  #     :numeric => "1",
  #     :uri => "http://www.example.com",
  #     :dateTime_iso8601 => "2013-01-01T13:00:00Z",
  #     :date_db => "2013-01-01",
  #     :dateTime_hms => "13:00:00"
  #   }.each do |type, content|
  #     it "should return the format of #{type} correctly" do
  #       row = [content]
  #
  #       validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #       validator.build_formats(row)
  #       formats = validator.instance_variable_get("@formats")
  #
  #       formats[0].keys.first.should == type
  #     end
  #   end
  #
  #   it "treats floats and ints the same" do
  #     row = ["12", "3.1476"]
  #
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     validator.build_formats(row)
  #     formats = validator.instance_variable_get("@formats")
  #
  #     formats[0].keys.first.should == :numeric
  #     formats[1].keys.first.should == :numeric
  #   end
  #
  #   it "should ignore blank arrays" do
  #     row = []
  #
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     validator.build_formats(row)
  #     formats = validator.instance_variable_get("@formats")
  #     formats.should == []
  #   end
  #
  #   it "should work correctly for single columns" do
  #     rows = [
  #         ["foo"],
  #         ["bar"],
  #         ["baz"]
  #       ]
  #
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #
  #     rows.each_with_index do |row, i|
  #       validator.build_formats(row)
  #     end
  #
  #     formats = validator.instance_variable_get("@formats")
  #
  #     formats.should == [{:string => 3}]
  #   end
  #
  #   it "should return formats correctly if a row is blank" do
  #     rows = [
  #         [],
  #         ["foo","1","$2345"]
  #       ]
  #
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #
  #     rows.each_with_index do |row, i|
  #       validator.build_formats(row)
  #     end
  #
  #     formats = validator.instance_variable_get("@formats")
  #
  #     formats.should == [
  #       {:string => 1},
  #       {:numeric => 1},
  #       {:string => 1},
  #     ]
  #   end
  #
  # end

  # context "csv dialect" do
  #   it "should provide sensible defaults for CSV parsing" do
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     opts = validator.instance_variable_get("@csv_options")
  #     opts.should include({
  #       :col_sep => ",",
  #       :row_sep => :auto,
  #       :quote_char => '"',
  #       :skip_blanks => false
  #     })
  #   end
  #
  #   it "should map CSV DDF to correct values" do
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     opts = validator.dialect_to_csv_options( {
  #       "lineTerminator" => "\n",
  #       "delimiter" => "\t",
  #       "quoteChar" => "'"
  #     })
  #     opts.should include({
  #       :col_sep => "\t",
  #       :row_sep => "\n",
  #       :quote_char => "'",
  #       :skip_blanks => false
  #     })
  #   end
  #
  # end
  #
  # context "when detecting headers" do
  #   it "should default to expecting a header" do
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     expect( validator.header? ).to eql(true)
  #   end
  #
  #   it "should look in CSV options to detect header" do
  #     opts = {
  #       "header" => true
  #     }
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv", opts)
  #     expect( validator.header? ).to eql(true)
  #     opts = {
  #       "header" => false
  #     }
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv", opts)
  #     expect( validator.header? ).to eql(false)
  #   end
  #
  #   it "should look in content-type for header=absent" do
  #     stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :headers=>{"Content-Type" => "text/csv; header=absent"}, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     expect( validator.header? ).to eql(false)
  #     expect( validator.errors.size ).to eql(0)
  #   end
  #
  #   it "should look in content-type for header=present" do
  #     stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :headers=>{"Content-Type" => "text/csv; header=present"}, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     expect( validator.header? ).to eql(true)
  #     expect( validator.errors.size ).to eql(0)
  #   end
  #
  #   it "assume header present if not specified in content type" do
  #     stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :headers=>{"Content-Type" => "text/csv"}, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     expect( validator.header? ).to eql(true)
  #     expect( validator.errors.size ).to eql(0)
  #     expect( validator.info_messages.size ).to eql(1)
  #     expect( validator.info_messages.first.type).to eql(:assumed_header)
  #   end
  #
  #   it "give undeclared header error if content type is wrong" do
  #     stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :headers=>{"Content-Type" => "text/html"}, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     expect( validator.header? ).to eql(true)
  #     expect( validator.errors.size ).to eql(2)
  #     expect( validator.errors[0].type).to eql(:wrong_content_type)
  #     expect( validator.errors[1].type).to eql(:undeclared_header)
  #     expect( validator.info_messages.size ).to eql(0)
  #   end
  #
  # end
  #
  # context "when validating headers" do
  #   it "should warn if column names aren't unique" do
  #     data = StringIO.new( "minimum, minimum" )
  #     validator = Csvlint::StreamingValidator.new(data)
  #     expect( validator.validate_header(["minimum", "minimum"]) ).to eql(true)
  #     expect( validator.warnings.size ).to eql(1)
  #     expect( validator.warnings.first.type).to eql(:duplicate_column_name)
  #     expect( validator.warnings.first.category).to eql(:schema)
  #   end
  #
  #   it "should warn if column names are blank" do
  #     data = StringIO.new( "minimum," )
  #     validator = Csvlint::StreamingValidator.new(data)
  #
  #     expect( validator.validate_header(["minimum", ""]) ).to eql(true)
  #     expect( validator.warnings.size ).to eql(1)
  #     expect( validator.warnings.first.type).to eql(:empty_column_name)
  #     expect( validator.warnings.first.category).to eql(:schema)
  #   end
  #
  #   it "should include info message about missing header when we have assumed a header" do
  #     data = StringIO.new( "1,2,3\r\n" )
  #     validator = Csvlint::StreamingValidator.new(data)
  #
  #     expect( validator.valid? ).to eql(true)
  #     expect( validator.info_messages.size ).to eql(1)
  #     expect( validator.info_messages.first.type).to eql(:assumed_header)
  #     expect( validator.info_messages.first.category).to eql(:structure)
  #   end
  #
  #   it "should not include info message about missing header when we are told about the header" do
  #     data = StringIO.new( "1,2,3\r\n" )
  #     validator = Csvlint::StreamingValidator.new(data, "header"=>false)
  #
  #     expect( validator.valid? ).to eql(true)
  #     expect( validator.info_messages.size ).to eql(0)
  #   end
  #
  #   it "should be an error if we have assumed a header, there is no dialect and there's no content-type" do
  #     stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :headers=>{}, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     expect( validator.valid? ).to eql(false)
  #   end
  #
  #   it "should not be an error if we have assumed a header, there is no dialect and content-type doesn't declare header, as we assume header=present" do
  #     stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :headers=>{"Content-Type" => "text/csv"}, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     expect( validator.valid? ).to eql(true)
  #   end
  #
  #   it "should be valid if we have a dialect and the data is from the web" do
  #     stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :headers=>{"Content-Type" => "text/csv"}, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #     #header defaults to true in csv dialect, so this is valid
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv", {})
  #     expect( validator.valid? ).to eql(true)
  #
  #     stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :headers=>{"Content-Type" => "text/csv"}, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv", {"header"=>true})
  #     expect( validator.valid? ).to eql(true)
  #
  #     stub_request(:get, "http://example.com/example.csv").to_return(:status => 200, :headers=>{"Content-Type" => "text/csv"}, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv", {"header"=>false})
  #     expect( validator.valid? ).to eql(true)
  #   end
  #
  # end
  #

  #
  # context "check_consistency" do
  #
  #   it "should return a warning if columns have inconsistent values" do
  #     formats = [
  #         {:string => 3},
  #         {:string => 2, :numeric => 1},
  #         {:numeric => 3},
  #       ]
  #
  #     validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #     validator.instance_variable_set("@formats", formats)
  #     validator.check_consistency
  #
  #     warnings = validator.instance_variable_get("@warnings")
  #     warnings.delete_if { |h| h.type != :inconsistent_values }
  #
  #     warnings.count.should == 1
  #   end
  #
  # end
  #
  # context "accessing metadata" do
  #
  #   before :all do
  #     stub_request(:get, "http://example.com/crlf.csv").to_return(:status => 200, :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','windows-line-endings.csv')))
  #   end
  #
  #   it "can get line break symbol" do
  #
  #     validator = Csvlint::StreamingValidator.new("http://example.com/crlf.csv")
  #     validator.line_breaks.should == "\r\n"
  #
  #   end
  #
  # end
  #
  # it "should give access to the complete CSV data file" do
  #   stub_request(:get, "http://example.com/example.csv").to_return(:status => 200,
  #       :headers=>{"Content-Type" => "text/csv; header=present"},
  #       :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #   validator = Csvlint::StreamingValidator.new("http://example.com/example.csv")
  #   expect( validator.valid? ).to eql(true)
  #   data = validator.data
  #   expect( data.count ).to eql 4
  #   expect( data[0] ).to eql ['Foo','Bar','Baz']
  #   expect( data[2] ).to eql ['3','2','1']
  # end
  #
  # it "should limit number of lines read" do
  #   stub_request(:get, "http://example.com/example.csv").to_return(:status => 200,
  #   :headers=>{"Content-Type" => "text/csv; header=present"},
  #   :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #   validator = Csvlint::StreamingValidator.new("http://example.com/example.csv", nil, nil, limit_lines: 2)
  #   expect( validator.valid? ).to eql(true)
  #   data = validator.data
  #   expect( data.count ).to eql 2
  #   expect( data[0] ).to eql ['Foo','Bar','Baz']
  # end
  #
  # it "should follow redirects to SSL" do
  #   stub_request(:get, "http://example.com/redirect").to_return(:status => 301, :headers=>{"Location" => "https://example.com/example.csv"})
  #   stub_request(:get, "https://example.com/example.csv").to_return(:status => 200,
  #       :headers=>{"Content-Type" => "text/csv; header=present"},
  #       :body => File.read(File.join(File.dirname(__FILE__),'..','features','fixtures','valid.csv')))
  #
  #   validator = Csvlint::StreamingValidator.new("http://example.com/redirect")
  #   expect( validator.valid? ).to eql(true)
  # end
end
