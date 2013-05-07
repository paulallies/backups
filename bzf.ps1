function zipfile($sourcefile, $compressedfile){
    $sevenZip = "C:\Program Files\7-Zip\7z.exe"
    & $sevenZip a -tzip $compressedfile $sourcefile

}


function ftpfile($SourceFile, $Destinationfile){
    $ftp = [System.Net.FtpWebRequest]::Create("ftp://ftp.drivehq.com/" + $Destinationfile)
    $ftp = [System.Net.FtpWebRequest]$ftp
    $ftp.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $ftp.Credentials = New-Object System.Net.NetworkCredential("paul.allies","bryce9")
    $ftp.UseBinary = $true
    $ftp.Timeout = -1
    $ftp.KeepAlive = $true
    $ftp.UsePassive = $true
    $content = [System.IO.File]::ReadAllBytes($SourceFile)
    $ftp.ContentLength = $content.Length
    # get the request stream, and write the bytes into it
    $rs = $ftp.GetRequestStream()
    $rs.Write($content, 0, $content.Length)
    # be sure to clean up after ourselves
    $rs.Close()
    $rs.Dispose()
   

}


### <Usage>
### $server = new-object ("Microsoft.SqlServer.Management.Smo.Server") 'Z002\SQL2K8'
### invoke-sqlbackup 'Z002\SqlExpress' 'pubs' $($server.BackupDirectory + "\pubs.bak")
### invoke-sqlrestore 'Z002\SqlExpress' 'pubs' $($server.BackupDirectory + "\pubs.bak") -force

$smoAssembly = [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
if (!($smoVersion))
{ Set-Variable -name SmoVersion  -value $smoAssembly.GetName().Version.Major -Scope Global -Option Constant -Description "SQLPSX variable" }
[void][reflection.assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended')
 
#######################
function Invoke-SqlBackup
{
    param($sqlserver=$(throw 'sqlserver required.'),$dbname=$(throw 'dbname required.'),$filepath=$(throw 'filepath required.')
          ,$action='Database', $description='',$name='',[switch]$force,[switch]$incremental,[switch]$copyOnly)
   
    #action can be Database or Log
 
    $server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $sqlserver
 
    Write-Verbose "Invoke-SqlBackup $($server.Name) $dbname"
 
    $backup = new-object ("Microsoft.SqlServer.Management.Smo.Backup")
    $backupDevice = new-object ("Microsoft.SqlServer.Management.Smo.BackupDeviceItem") $filepath, 'File'
 
    $backup.Action = $action
    $backup.BackupSetDescription = $description
    $backup.BackupSetName = $name
    if (!$server.Databases.Contains("$dbname")) {throw 'Database $dbname does not exist on $($server.Name).'}
    $backup.Database = $dbname
    $backup.Devices.Add($backupDevice)
    $backup.Initialize = $($force.IsPresent)
    $backup.Incremental = $($incremental.IsPresent)
    if ($copyOnly)
    { if ($server.Information.Version.Major -ge 9 -and $smoVersion -ge 10)
      { $backup.CopyOnly = $true }
      else
      { throw 'CopyOnly is supported in SQL Server 2005(9.0) or higher with SMO version 10.0 or higher.' }
    }
   
    trap {
        $ex = $_.Exception
        Write-Output $ex.message
        $ex = $ex.InnerException
        while ($ex.InnerException)
        {
            Write-Output $ex.InnerException.message
            $ex = $ex.InnerException
        };
        continue
    }
    $backup.SqlBackup($server)
   
    if ($?)
    { Write-Host "$action backup of $dbname to $filepath complete." }
    else
    { Write-Host "$action backup of $dbname to $filepath failed." }

    write "Zipping File..."
    $datestamp = Get-Date -Format 'yyyyMMddhhmm'

    zipfile -sourcefile $filepath -compressedfile "$filepath$datestamp.zip"

    Remove-Item $filepath
    
    


    #ftpfile -SourceFile "$filepath.zip" -Destinationfile "$dbname$datestamp.zip"
   # Remove-Item "$filepath.zip"
   
}
 #cd C:\backups\nmp

Invoke-SqlBackup -sqlserver '.\sqlexpress' -dbname 'nmp' -filepath 'c:\backups\nmp\nmp.bak'
Invoke-SqlBackup -sqlserver '.\sqlexpress' -dbname 'mikateko' -filepath 'c:\backups\nmp\mikateko.bak'
Invoke-SqlBackup -sqlserver '.\sqlexpress' -dbname 'cedar' -filepath 'c:\backups\nmp\cedar.bak'

write "Uploading File..."
cd C:\backups\nmp
git add .
git commit -m 'new dbs'
write "Commits complete..."
git push origin master
 write "Success!!"
 