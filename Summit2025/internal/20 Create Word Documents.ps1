# Script to generate a Word document based on data from Apps.csv
# Each record will be on a separate page with Key, UserName, DisplayName and AppId properties
# Each page starts with the same sentence

param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath
)

$csvData = Import-Csv -Path $csvPath

# Create a Word application instance
$word = New-Object -ComObject Word.Application
$word.Visible = $false

# Create a new document
$document = $word.Documents.Add()

# Set the default font size for the entire document to 16 points
$document.Content.Font.Size = 16

# Define the standard sentence to be included on each page
$standardSentence = @'
Hello attendee,

This piece of paper is important for the hands-on labs. It contains the information you need to access the labs. Please keep it safe and do not lose it.
'@

$tinyUrl = 'If you have some time before the workshop starts, please get prepared: https://aka.ms/EntraIDM365AsCodeDSCWorkshop'

$title = 'Entra ID and M365 as Code with DSC workshop'

# Loop through each record in the CSV
for ($i = 0; $i -lt $csvData.Count; $i++)
{
    $record = $csvData[$i]

    # Add the title at the top of the page
    $titleParagraph = $document.Paragraphs.Add()
    $titleParagraph.Range.Text = $title
    $titleParagraph.Range.Font.Bold = $true
    $titleParagraph.Range.Font.Size = 24
    $titleParagraph.Alignment = 1 # Center alignment (0=left, 1=center, 2=right)
    $titleParagraph.Range.InsertParagraphAfter()

    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = '' # Empty paragraph for spacing
    $paragraph.Range.Font.Size = 16
    $paragraph.Range.Font.Bold = $true
    $paragraph.Alignment = 0 # Center alignment (0=left, 1=center, 2=right)
    $paragraph.Range.InsertParagraphAfter()

    # Add the standard sentence after the title
    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = $standardSentence
    $paragraph.Range.Font.Size = 16
    $paragraph.Range.Font.Bold = $true
    $paragraph.Alignment = 0 # Center alignment (0=left, 1=center, 2=right)
    $paragraph.Range.InsertParagraphAfter()

    # Add the standard sentence after the title
    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = $tinyUrl
    $paragraph.Range.Font.Size = 16
    $paragraph.Range.Font.Bold = $true
    $paragraph.Range.InsertParagraphAfter()

    # Add the record data
    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = "UserName: $($record.UserName)"
    $paragraph.Range.InsertParagraphAfter()

    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = "User UPN: $($record.UserUpn)"
    $paragraph.Range.InsertParagraphAfter()

    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = "Key: $($record.Key)"
    $paragraph.Range.InsertParagraphAfter()

    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = "DisplayName: $($record.DisplayName)"
    $paragraph.Range.InsertParagraphAfter()

    $paragraph = $document.Paragraphs.Add()
    $paragraph.Range.Text = "AppId: $($record.AppId)"
    $paragraph.Range.InsertParagraphAfter()

    # If this is not the last record, add a page break
    if ($i -lt $csvData.Count - 1)
    {
        $paragraph.Range.InsertBreak(7) # 7 is the value for wdPageBreak
    }
}

# Save the document
$outputPath = Join-Path -Path $PSScriptRoot -ChildPath 'SummitAppsDocument.docx'
$document.SaveAs($outputPath)
$document.Close()

# Close Word
$word.Quit()

# Release COM objects
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($document) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "Document generated successfully at: $outputPath"
