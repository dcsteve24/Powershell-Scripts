Param([Parameter(Position=0)][string]$vpcPath, [Parameter(Position=1)][string]$380thPath, [Parameter(Position=2)][string]$finalPath)

#This script was designed to take EXCEL input from the military VPC Generator, and the current tracker 
# grab information needed, then output it as the new "tracker". Eliminated manual updating.

##Self reference -- Excel reading, updating and formatting through Powershell
#------------------------------------------------------------

#-------------------------Functions--------------------------
#Function to ask for required data if not passed in variable of script
#Input: Question as string, Answer as string
#Output: Answer as string
Function AskData ([string]$question, [string]$answer, [string] $predictedPath) {
    if ($answer -eq [string]::Empty) { #if a parameter wasnt passed at startup
        $answer = Read-Host -Prompt $question
        if ($answer -eq [string]::Empty) { #if user accepted defaults
            $answer = $predictedPath
        }
    }
    return $answer           
}    

#Function to calculate the closeout date based on rank and SCOD Closout Dates
#Input: Rank as String (ALL CAPS)
#Output: a Closout Date in MM/DD/YYYY Format
Function CalculateNextCloseoutDate ([string]$rank, [DateTime]$currentCloseout, [string]$status) {
    #SrA and below = 31 Mar (TR Even)
    #SSgt = 31 Jan (TR Odd)
    #TSgt = 30 Nov (TR Even)
    #MSgt = 30 Sep (TR Odd)
    #SMSgt = 31 Jul (TR Even)
    #CMSgt = 31 May (TR Odd)
    #AGR Due every year
    #TR due every two years on even/odd years as noted
    $nextCloseout = [dateTime]"1/1/1999" #set default Datetime (to catch errors or no date time assigned)
    switch -wildcard ($rank.ToUpper()) {
        "AB" {   $currentCloseoutYear = ($currentCloseout).Year.ToString()
                    $nextCloseout = [dateTime]"03/31/$currentCloseoutYear"
                    if ($status -contains "TR") { $nextCloseout = ($nextCloseout).AddYears(2) }
                    else { $nextCloseout = ($nextCloseout).AddYears(1) } 
                }
        "A1C" {  $currentCloseoutYear = ($currentCloseout).Year.ToString()
                    $nextCloseout = [dateTime]"03/31/$currentCloseoutYear"
                    if ($status -contains "TR") { $nextCloseout = ($nextCloseout).AddYears(2) }
                    else { $nextCloseout = ($nextCloseout).AddYears(1) } 
                }
        "SRA" {  $currentCloseoutYear = ($currentCloseout).Year.ToString()
                    $nextCloseout = [dateTime]"03/31/$currentCloseoutYear"
                    if ($status -contains "TR") { $nextCloseout = ($nextCloseout).AddYears(2) }
                    else { $nextCloseout = ($nextCloseout).AddYears(1) } 
                }
        "SSG*" { $currentCloseoutYear = ($currentCloseout).Year.ToString()
                    $nextCloseout = [dateTime]"01/31/$currentCloseoutYear"
                    if ($status -contains "TR") { $nextCloseout = ($nextCloseout).AddYears(2) }
                    else { $nextCloseout = ($nextCloseout).AddYears(1) } 
                }
        "TSG*" { $currentCloseoutYear = ($currentCloseout).Year.ToString()
                    $nextCloseout = [dateTime]"11/30/$currentCloseoutYear"
                    if ($status -contains "TR") { $nextCloseout = ($nextCloseout).AddYears(2) }
                    else { $nextCloseout = ($nextCloseout).AddYears(1) } 
                }
        "MSG*" { $currentCloseoutYear = ($currentCloseout).Year.ToString()
                    $nextCloseout = [dateTime]"09/30/$currentCloseoutYear"
                    if ($status -contains "TR") { $nextCloseout = ($nextCloseout).AddYears(2) }
                    else { $nextCloseout = ($nextCloseout).AddYears(1) } 
                }
        "SMS*" { $currentCloseoutYear = ($currentCloseout).Year.ToString()
                    $nextCloseout = [dateTime]"07/31/$currentCloseoutYear"
                    if ($status -contains "TR") { $nextCloseout = ($nextCloseout).AddYears(2) }
                    else { $nextCloseout = ($nextCloseout).AddYears(1) } 
                }
        "CMS*" { $currentCloseoutYear = ($currentCloseout).Year.ToString()
                    $nextCloseout = [dateTime]"05/31/$currentCloseoutYear"
                    if ($status -contains "TR") { $nextCloseout = ($nextCloseout).AddYears(2) }
                    else { $nextCloseout = ($nextCloseout).AddYears(1) } 
                }
    }
    if ($nextCloseout -eq [dateTime]"1/1/1999") { #if still default, its an officer
        $nextCloseout = "N/A -- Officer"
    } 
    return $nextCloseout
}

#Function to calculate the SCOD date based on rank
#Input: Rank as String (ALL CAPS)
#Output: a SCOD Date in DDMMM Format
Function CalculateSCOD ([string]$rank) {
    #SrA and below = 31 Mar (TR Even)
    #SSgt = 31 Jan (TR Odd)
    #TSgt = 30 Nov (TR Even)
    #MSgt = 30 Sep (TR Odd)
    #SMSgt = 31 Jul (TR Even)
    #CMSgt = 31 May (TR Odd)
    #AGR Due every year
    #TR due every two years on even/odd years as noted
    $SCOD = "Officer" #sets default to officer
    switch -wildcard ($rank.ToUpper()) {
        "AB" { $SCOD = "31 MAR" }    
        "A1C" { $SCOD = "31 MAR" }
        "SRA" { $SCOD = "31 MAR" }
        "SSG*" { $SCOD = "31 JAN" }
        "TSG*" { $SCOD = "30 NOV" }
        "MSG*" { $SCOD = "30 SEP" }
        "SMS*" { $SCOD = "31 JUL" }
        "CMS*" { $SCOD = "31 MAY" }
    }
    return $SCOD
}

#Function to export the finalpath File
#Input: finalpath Excel file path as String
#Output: Finalized Excel File
Function ExportData ([string]$finalPath, [object]$380thData) {
    #for Excel border settings reference this here https://social.technet.microsoft.com/Forums/en-US/b0e65ce1-e12d-4ec5-b5df-992776182367/excel-cell-formatting-boarders?forum=winserverpowershell
    $borderStyle = 1 #value of style to continous
    $borderWeight = 2 #value of weight to thin
    $borderClear = -4142 #value of weight to no border
    $centerAlignment = -4108 #value for center alignment
    $objExcel = New-Object -ComObject Excel.Application #Makes a new Excel Object
    $objExcel.Visible = $false #Disable the visible property to prevent it from opening in Excel 
    $workBook = $objExcel.workbooks.open($finalPath) #Opens the workbook
    $sheetArray = $workBook.Sheets | Select-Object -Property Name #Pulls all the available sheets into an array
    $workSheet = $workBook.sheets.item($sheetArray.name[0]) #Opens the workbooks sheet (first sheet)
    $380thData = $380thData | Sort Name #sort the array by name before exporting to excel

    Write-Host "Clearing Data..." #We clear the data in case numbers shrink, so we don't have leftover people
    $usedRange = $workSheet.UsedRange #set current used range
    $usedRange.Borders.LineStyle = $borderClear #clears the borders
    ForEach($row in ($usedRange.Rows | Select -skip 1)){ #for each used row, skipping the headers
        $row.clear() | Out-Null #clear the row; catches the true statements
    }

    Write-Host "Exporting 380th Data..."
    for ($x = 0; $x -lt $380thData.Length; $x++) { #Loop through the objects
        $row = $x+2 #we need to skip the headers so we add +1 to x
        $workSheet.cells.item($row, 1) = $380thData[$x].Name
        $workSheet.cells.item($row, 2) = $380thData[$x].Rank
        $workSheet.cells.item($row, 3) = $380thData[$x].Status
        $workSheet.cells.item($row, 4) = $380thData[$x].Rater
        $workSheet.cells.item($row, 5) = $380thData[$x]."Last ACA Date"
        $workSheet.cells.item($row, 6) = $380thData[$x].DOR
        $workSheet.cells.item($row, 7) = $380thData[$x]."Current Report Closeout"
        $workSheet.cells.item($row, 8) = $380thData[$x]."Current Report Status"
        $workSheet.cells.item($row, 9) = $380thData[$x].SCOD
        $workSheet.cells.item($row, 10) = $380thData[$x]."Next Closeout"
        $workSheet.cells.item($row, 11) = $380thData[$x]."Notes"
    }
    
    Write-Host "Reformatting..."
    $usedRange = $workSheet.UsedRange #set the new used range after population
    $usedRange.EntireColumn.AutoFit() | Out-Null #AutoSize the columns
    For ($row = 1; $row -le ($380thData.Length + 1); $row ++) { #+1 for headers
        For ($col = 1; $col -le 11; $col++) { #11 columns
            $workSheet.Cells.Item($row, $col).BorderAround($borderStyle, $borderWeight) | Out-Null #sets borders on everything
            if ($col -ne 1) { #Center Aligns all columns except Name
                $workSheet.Cells.Item($row, $col).HorizontalAlignment = $centerAlignment
                $workSheet.Cells.Item($row, $col).VerticalAlignment = $centerAlignment
            }
        }
    }
    $workBook.SaveAs($finalPath) #Save the final to the location
    $objExcel.workbooks.close() #Close the Excel
    $objExcel.quit()
    kill -processname EXCEL
    Write-Host "Export Finished..."
    return $data
}

#Function to import the 380th Excel File and populate it
#Input: 380th Excel file path as String
#Output: PSObject with desired information from current information of 380th sheet
Function Import380th ([string]$380thPath) {
    $objExcel = New-Object -ComObject Excel.Application #Makes a new Excel Object
    $objExcel.Visible = $false #Disable the visible property to prevent it from opening in Excel 
    $workBook = $objExcel.workbooks.open($380thPath) #Opens the workbook
    $sheetArray = $workBook.Sheets | Select-Object -Property Name #Pulls all the available sheets into an array
    $workSheet = $workBook.sheets.item($sheetArray.name[0]) #Opens the workbooks sheet (first sheet)
    $usedRange = $workSheet.usedrange #Sets the range of used cells (contains information)

    Write-Host "Importing 380th Data..."
    $data = ForEach($row in ($usedRange.Rows | Select -skip 1)){ #skip the headers
                New-Object PSObject -Property @{
                    "Name" = $row.cells.item(1).value2
                    "Rank" = $row.cells.item(2).value2
                    "Status" = $row.cells.item(3).value2
                    "Rater" = $row.cells.item(4).value2
                    "Last ACA Date" = $row.cells.item(5).value2
                    "DOR" = $row.cells.item(6).value2
                    "Current Report Closeout" = $row.cells.item(7).value2
                    "Current Report Status" = $row.cells.item(8).value2
                    "SCOD" = $row.cells.item(9).value2
                    "Next Closeout" = $row.cells.item(10).value2
                    "Notes" = $row.cells.item(11).value2
                }
            }
    $objExcel.workbooks.close() #Close the Excel
    $objExcel.quit()
    kill -processname EXCEL
    Write-Host "Import Finished..."
    return $data
}

#Function to import the VPC Report Excel File
#Input: VPC file path as String
#Output: PSObject with desired information from VPC sheet
Function ImportVPC ([string]$vpcpath) {
    $objExcel = New-Object -ComObject Excel.Application #Makes a new Excel Object
    $objExcel.Visible = $false #Disable the visible property to prevent it from opening in Excel 
    $workBook = $objExcel.workbooks.open($vpcpath) #Opens the workbook
    $sheetArray = $workBook.Sheets | Select-Object -Property Name #Pulls all the available sheets into an array
    $workSheet = $workBook.sheets.item($sheetArray.name[0]) #Opens the workbooks sheet (first sheet)
    $usedRange = $workSheet.usedrange #Sets the range of used cells (contains information)

    Write-Host "Importing VPC Data..."
    $data = ForEach($row in ($usedRange.Rows | Select -skip 5)){ #skip the headers and PII statement
                if ($row.cells.item(10).value2 -ne $null) { #dont run if Last Name not present (prevents empty fields)
                    New-Object PSObject -Property @{
                        "Name" = $row.cells.item(10).value2 + ", " + $row.cells.item(8).value2 + " " + $row.cells.item(9).value2 #Name = Last, First Middle out of VPC Report
                        "Rank" = $row.cells.item(7).value2 #Rank = Grade from VPC Report
                        "Current Report Closeout" = $row.cells.item(4).Value2 #Current Report Closeout = CloseOut Date out of VPC report
                    }
                }
            }
    $objExcel.workbooks.close() #Close the Excel
    $objExcel.quit()
    kill -processname EXCEL
    Write-Host "Import Finished..."
    return $data
}

#Function to compare data and populate data from vpc import to current data
#Input: VPC data as object, 380thination data as object
#Output: PSObject with final data
Function PopulateData([Object]$vpcData, [Object]$380thData) {
    #----------------Populate from VPC to 380th-----------------------------
    #Then add and update fields from VPC to 380th (in VPC and 380th)
    Write-Host "Comparring and populating internal data..."
    for ($x = 0; $x -lt $vpcData.Length; $x++) { #Looping through the vpc data
        $380thIndex = $380thData.Name.IndexOf($vpcData.Name[$x]) #returns index of entry, -1 if not found 380thData
        if ($380thIndex -ne -1) { #if found -- populate the information
            $380thData[$380thIndex].Rank = $vpcData[$x].Rank
            $380thData[$380thIndex]."Current Report Closeout" = $vpcData[$x]."Current Report Closeout"
            $380thData[$380thIndex]."Current Report Status" = $vpcData[$x]."Current Report Status"
            $380thData[$380thIndex].SCOD = CalculateSCOD $vpcData[$x].Rank #Call functin passing grade from VPC as input, expects a date in return
            $380thData[$380thIndex]."Next Closeout" = CalculateNextCloseoutDate $vpcData[$x].Rank $vpcData[$x]."Current Report Closeout" $380thData[$380thIndex].Status #Call function passing grade from VPC as input, expecting a date returned
        } 
        else { #Create a new entry if we arent tracking them (in VPC but not 380th)
            $380thData += New-Object PSObject -Property @{
                            "Name" = $vpcData[$x].Name
                            "Rank" = $vpcData[$x].Rank
                            "Current Report Closeout" = $vpcData[$x]."Current Report Closeout"
                            "Current Report Status" = $vpcData[$x]."Current Report Status"
                            "SCOD" = CalculateSCOD $vpcData[$x].Rank #Call function passing grade from VPC as input, expects a date in return
                            "Next Closeout" = CalculateNextCloseoutDate $vpcData[$x].Rank $vpcData[$x]."Current Report Closeout" "TR" #Call function passing grade from VPC as input, expecting a date returned; assumes TR. Can be changed later in spreadsheet
                         }
        }
    }
    Write-Host "Finished populating..."
    return $380thData
}

#-------------------Driver Code--------------------------------
$predictedVPCPath = "$PWD\VPC_report.xls"
$predicted380Shell = "$PWD\380th SPCS Shell Tracker.xls"
$predictedFinalName = "$PWD\380th SPCS Shell Tracker Final.xls"
$vpcpath = AskData "Please provide the path to the VPC export [$predictedVPCPath]" $vpcPath $predictedVPCPath #Set the VPC path 
if (!(Test-Path -Path $vpcpath)) {  #Make sure we can reach the path before proceeding.
    do { $vpcpath = AskData "The entry you provided could not be reached from this shell, please ensure you have provided the correct information and provide it again"}
    while (!(Test-Path -Path $vpcpath)) 
}
$380thPath = AskData "Please provide the path to the 380th file [$predicted380Shell]" $380thPath $predicted380Shell #Set the 380th Path
if (!(Test-Path -Path $380thPath)) { #Make sure we can reach the path before proceeding.
    do { $380thPath = AskData "The entry you provided could not be reached from this shell, please ensure you have provided the correct information and provide it again"}
    while (!(Test-Path -Path $380thPath))  
}
$finalPath = AskData "Please provide the desired path of the final file [$predictedFinalName]" $finalPath $predictedFinalName #set the Final Path
Copy-Item -Path $380thPath -Destination $finalPath #Creates a copy of the 380thpath into the finalpath so we dont overwrite it if there are errors
$vpcData = ImportVPC $vpcpath | Sort-Object -Property Name #Call the fucntion to grab the data from the VPC file and sort by name
$380thData = Import380th $380thPath | Sort-Object -Property Name #Call the function to grab the data from the 380th file and sort by name
$380thData = PopulateData $vpcData $380thData #Populates the arrays with correct information
ExportData $finalPath $380thData #Export the data to the desired destination
