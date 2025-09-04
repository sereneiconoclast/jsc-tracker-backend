#!/usr/bin/env ruby
require 'pp'
require 'pathname'
require 'active_support/core_ext/string/inflections' # camelize

# Script to generate CloudFormation templates from Lambda handler metadata
#
# I considered using YAML (Psych) for this. Then you have to strip off the initial
# document separator ("---"). Assembling the raw string seems easier, frankly.
class CloudFormationTemplateBuilder
  def initialize
    @lib_dir = Pathname.new(__dir__).parent / 'lib'
  end

  attr_accessor :debug
  alias_method :debug?, :debug

  def operations
    @operations ||= begin
      handler_files.map do |file|
        parse_operation_metadata(file.read, file.basename.to_s)
      end.compact.reduce(&:merge).tap { say("\n") }
    end
  end

  def lambda_function(operation_name)
    operation = operations[operation_name]
    raise "Operation '#{operation_name}' not found" unless operation

    function_name = "JSCTracker#{operation_name}"
    handler_name = "#{operation[:filename]}.lambda_handler"

    # Indented by 2 spaces
    <<YAML
  #{function_name}LambdaFunction:
    Type: 'AWS::Lambda::Function'
    Properties:
      FunctionName: '#{function_name}'
      Handler: '#{handler_name}'
      Role:
        !ImportValue 'jsc-tracker-dynamodb-JSCTrackerDynamoDBRoleArn'
      Code:
        S3Bucket: 'static.us-west-2.infinitequack.net'
        S3Key: 'lambda/jsc-tracker-lambda.zip'
      Runtime: ruby3.3
      Timeout: 30
      MemorySize: 128
YAML
  end

  def lambda_function_arn_stack_output(operation_name)
    operation = operations[operation_name]
    raise "Operation '#{operation_name}' not found" unless operation

    function_name = "JSCTracker#{operation_name}"

    # Indented by 2 spaces
    <<YAML
  #{function_name}LambdaFunctionArn:
    Description: 'ARN of the #{operation_name} Lambda function'
    Value: !GetAtt #{function_name}LambdaFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-#{function_name}LambdaFunctionArn'
YAML
  end

  def lambda_template
    out = <<~YAML
      AWSTemplateFormatVersion: '2010-09-09'
      Description: 'CloudFormation template for JSCTracker Lambda functions'

      Resources:
    YAML
    out << (
      operations.keys.map(&method(:lambda_function)).join("\n")
    )

    out << "\nOutputs:\n"
    out << (
      operations.keys.map(&method(:lambda_function_arn_stack_output)).join('')
    )

    out
  end

  private

  def say(s)
    puts(s) if debug?
  end

  def handler_files
    @handler_files ||= begin
      say "Scanning for Lambda handler files in #{@lib_dir}..."

      @lib_dir.glob('*.rb').select do |file|
        file.read.include?('def lambda_handler')
      end.sort.tap do |found|
        if debug?
          puts "Found #{found.length} handler files:"
          found.each { |file| puts "  - #{file.basename}" }
          puts
        end
      end
    end
  end

  HTTP_VERB_PATTERN = %r!^HttpVerb:\s*([A-Z]+)$!
  PATH_PATTERN = %r!^Path:\s*(/[a-z_{}/]+)$!
  QUERY_PATTERN = %r!^Query:\s*(REQUIRED|OPTIONAL)\s+([a-z_]+)$!

  def parse_operation_metadata(content, filename)
    say "Parsing #{filename}..."

    # Extract the operation name from filename (remove .rb extension and CamelCase)
    filename = filename.gsub(/\.rb$/, '')
    operation_name = filename.camelize

    # Find the =begin / =end block
    metadata_block = content.match(/=begin\nOPERATION METADATA:\n(.*?)\n=end/m)
    return say("  ✗ No operation metadata found") unless metadata_block

    metadata_text = metadata_block[1]

    # Parse the metadata into a hash
    operation = { filename: filename, query: {} }

    metadata_text.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#') # allow embedded comments

      if (verb = line.match(HTTP_VERB_PATTERN)&.match(1))
        raise "Double verb in #{metadata_text}" if operation[:http_verb]
        operation[:http_verb] = verb
      elsif (path = line.match(PATH_PATTERN)&.match(1))
        raise "Double path in #{metadata_text}" if operation[:path]
        operation[:path] = path
      elsif (m = line.match(QUERY_PATTERN))
        required = m.match(1) == 'REQUIRED'
        param_name = m.match(2)
        raise "Double param '#{param_name}' in #{metadata_text}" if operation[:query][param_name]
        operation[:query][param_name] = required
      else
        raise "Unexpected line '#{line}' in #{metadata_text}"
      end
    end

    say "  ✓ Parsed: #{operation_name} #{operation[:http_verb]} #{operation[:path]}"

    { operation_name => operation }
  end
end

# Run the script
if __FILE__ == $0
  builder = CloudFormationTemplateBuilder.new
  case ARGV[0]
  when 'operations'
    builder.debug = true
    raise "No argument expected" if ARGV[1]
    operations = builder.operations
    puts "Parsed Operations:"
    puts "=" * 50
    pp (operations)
    puts
    puts "Total operations: #{operations.size}"
  when 'template'
    case ARGV[1]
    when 'lambda'
      puts(builder.lambda_template)
    else raise "Expected 'lambda'"
    end
  when 'operation'
    case ARGV[1]
    when 'lambda'
      puts(builder.lambda_function(ARGV[2]))
    when 'output'
      puts(builder.lambda_function_arn_stack_output(ARGV[2]))
    else raise "Expected 'lambda' or 'output'"
    end
  else raise "Expected 'operations', 'template', or 'operation'"
  end
end
