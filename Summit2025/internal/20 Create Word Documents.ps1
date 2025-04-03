# Script to generate a Word document based on data from Apps.csv
# Each record will be on a separate page with Key, UserName, DisplayName and AppId properties
# Each page starts with the same sentence

# Import CSV data
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "Apps.csv"
$csvData = Import-Csv -Path $csvPath

# Create a Word application instance
$word = New-Object -ComObject Word.Application
$word.Visible = $false

# Create a new document
$document = $word.Documents.Add()

# Define the standard sentence to be included on each page
$standardSentence = "Hello attendee, this piece of pater is important for the hands-on labs."

# Loop through each record in the CSV
for ($i = 0; $i -lt $csvData.Count; $i++) {
    $record = $csvData[$i]

    # Add the standard sentence at the top of the page
    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = $standardSentence
    $paragraph.Range.Font.Bold = $true
    $paragraph.Range.InsertParagraphAfter()

    # Add the record data
    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = "Key: $($record.Key)"
    $paragraph.Range.InsertParagraphAfter()

    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = "UserName: $($record.UserName)"
    $paragraph.Range.InsertParagraphAfter()

    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = "DisplayName: $($record.DisplayName)"
    $paragraph.Range.InsertParagraphAfter()

    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = "AppId: $($record.AppId)"
    $paragraph.Range.InsertParagraphAfter()

    # If this is not the last record, add a page break
    if ($i -lt $csvData.Count - 1) {
        $paragraph.Range.InsertBreak(7) # 7 is the value for wdPageBreak
    }
}

# Save the document
$outputPath = Join-Path -Path $PSScriptRoot -ChildPath "SummitAppsDocument.docx"
$document.SaveAs([ref]$outputPath)
$document.Close()

# Close Word
$word.Quit()

# Release COM objects
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($document) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "Document generated successfully at: $outputPath"
