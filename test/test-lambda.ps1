# PowerShell script for testing deployed Lambda functions directly
# Usage: Test-PostUserUserId -FieldName "slack_profile" -FieldValue "https://jsc-official.slack.com/team/U089S7PTLAK" -AccessToken "your-access-token-here"

function Test-PostUserUserId {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FieldName,

        [Parameter(Mandatory=$true)]
        [string]$FieldValue,

        [Parameter(Mandatory=$true)]
        [string]$AccessToken
    )

    # Lambda function name (you may need to adjust this based on your deployment)
    $LambdaFunctionName = "JSCTrackerPostUserUserId"

    # AWS region
    $Region = "us-west-2"

    # Construct the event payload
    $event = @{
        pathParameters = @{
            user_id = "-"
        }
        queryStringParameters = @{
            access_token = $AccessToken
        }
        headers = @{
            origin = "https://static.infinitequack.net"
        }
        body = (@{
            $FieldName = $FieldValue
        } | ConvertTo-Json -Compress)
    }

    # Convert to JSON
    $eventJson = $event | ConvertTo-Json -Depth 10 -Compress

    Write-Host "Invoking Lambda function: $LambdaFunctionName" -ForegroundColor Yellow
    Write-Host "Event payload:" -ForegroundColor Cyan
    Write-Host $eventJson -ForegroundColor Gray
    Write-Host ""

    try {
        # Invoke the Lambda function
        $response = aws lambda invoke `
            --function-name $LambdaFunctionName `
            --region $Region `
            --payload $eventJson `
            --cli-binary-format raw-in-base64-out `
            response.json

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Lambda invocation successful!" -ForegroundColor Green
            Write-Host "Response:" -ForegroundColor Cyan

            # Read and display the response
            if (Test-Path "response.json") {
                $responseContent = Get-Content "response.json" -Raw | ConvertFrom-Json
                Write-Host ($responseContent | ConvertTo-Json -Depth 10) -ForegroundColor White

                # Clean up response file
                Remove-Item "response.json" -Force
            }
        } else {
            Write-Host "Lambda invocation failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            Write-Host "AWS CLI output:" -ForegroundColor Red
            Write-Host $response -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error invoking Lambda function:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Example usage:
# Test-PostUserUserId -FieldName "slack_profile" -FieldValue "https://jsc-official.slack.com/team/U089S7PTLAK" -AccessToken "ya29.a0AfB_byC..."
