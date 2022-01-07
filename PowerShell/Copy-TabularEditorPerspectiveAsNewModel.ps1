[CmdletBinding()]

PARAM(

[Parameter(Mandatory= $true
,HelpMessage= "new Tabular Editor Folder Save")]
[ValidateNotNullorEmpty()][ValidateScript({
            IF (Test-Path -PathType Container -Path $_ -IsValid) 
                {$True}
            ELSE {
                Throw "$_ is not a Directory."
            } 
        })][String]$DestinationDirectory
,
[Parameter(Mandatory= $true
,HelpMessage= "Source folder of Tabular Editor Folder Save")]
[ValidateNotNullorEmpty()][ValidateScript({
             IF (Test-Path -PathType Container -Path $_ ) 
                 {$True}
             ELSE {
                 Throw "$_ is not a Directory."
             } 
         })][String]$SourceDirectory
,[Parameter(Mandatory= $true
,HelpMessage= "Name of Perspective to be split out. All measure and hierarchy column dependencies must be included in the perspective - its contents must stand alone.")]
[String]$PerspectiveName
)

function Remove-EmptyFoldersRecursively {
#https://stackoverflow.com/a/28637537
# A script block (anonymous function) that will remove empty folders
# under a root folder, using tail-recursion to ensure that it only
# walks the folder tree once. -Force is used to be able to process
# hidden files/folders as well.
    param(
        $Path
    )
    foreach ($childDirectory in Get-ChildItem -Force -LiteralPath $Path -Directory) {
        Remove-EmptyFoldersRecursively -Path $childDirectory.FullName
    }
    $currentChildren = Get-ChildItem -Force -LiteralPath $Path
    $isEmpty = $currentChildren -eq $null
    if ($isEmpty) {
        Write-Verbose "Removing empty folder at path '${Path}'." -Verbose
        Remove-Item -Force -LiteralPath $Path
    }
}


#set perspectives and relationships to save as files.
#override annotation serialization on the save window.


new-item -itemtype Directory $DestinationDirectory;
#cd $DestinationDirectory;
ls $SourceDirectory |copy -Recurse -Filter {PSIsContainer} -Destination $DestinationDirectory

#Bring the model-level things we need, but leave perspectives behind, as the whole point is to manage our 
#model like we have enterprise edition but deploy it like we don't, i.e. on cheaper standard edition SSAS servers. 
Get-ChildItem "$SourceDirectory\dataSources\" | Copy-Item -Destination "$DestinationDirectory\dataSources\";
Get-ChildItem "$SourceDirectory\roles\" | Copy-Item -Destination "$DestinationDirectory\roles\";
Get-ChildItem "$SourceDirectory\relationships\" | Copy-Item -Destination "$DestinationDirectory\relationships\";

$json = Get-Content "$SourceDirectory\perspectives\$($PerspectiveName).json" | ConvertFrom-Json;

$json.Tables | ForEach-Object {
    $tableName = $_.Name;
    $tablePath = "$SourceDirectory\tables\" + $tableName + '\' + $tableName + '.json';
    $tableDestPath = "$DestinationDirectory\tables\" + $tableName + '\' + $tableName + '.json';
    Get-ChildItem $tablePath | Copy-Item -Destination $tableDestPath ;
    $tablePartitionPath = "$SourceDirectory\tables\" + $tableName + '\partitions\' ;
    $tablePartitionDestPath = "$DestinationDirectory\tables\" + $tableName + '\partitions\' ;
    Get-ChildItem $tablePartitionPath | Copy-Item -Destination $tablePartitionDestPath ;
    $_.Columns | %{
         $columnPath = "$SourceDirectory\tables\" + $tableName + '\columns\' + $_.Name + '.json' ;
         $columnDestPath = "$DestinationDirectory\tables\" + $tableName + '\columns\' + $_.Name + '.json' ;
        Get-ChildItem $columnPath | Copy-Item -Destination $columnDestPath ;
    }
    ;
    if ($_.Measures.Count -gt 0) {
        $_.Measures | %{
            $measurePath = "$SourceDirectory\tables\" + $tableName + '\measures\' + $_.Name + '.json';
            $measureDestPath = "$DestinationDirectory\tables\" + $tableName + '\measures\' + $_.Name + '.json';
            Get-ChildItem $measurePath | Copy-Item -Destination $measureDestPath;
        }
    } ;
    if ($_.Hierarchies.Count -gt 0) {
        $_.Hierarchies | %{
            $hierarchyPath = "$SourceDirectory\tables\" + $tableName + '\hierarchies\' + $_.Name + '.json';
            $hierarchyDestPath = "$DestinationDirectory\tables\" + $tableName + '\hierarchies\' + $_.Name + '.json';
            Get-ChildItem $hierarchyPath | Copy-Item -Destination $hierarchyDestPath;
        }
    }
}

#then use Remove-EmptyFoldersRecursively on the new destination folders.
Remove-EmptyFoldersRecursively -Path $DestinationDirectory;

#Then launch Tabular Editor and open the folder-save in $DestinationDirectory to 
#manually clean up relationships that don't have all of their pieces anymore.

