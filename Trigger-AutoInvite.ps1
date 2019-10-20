$MAX_LOGS = 5
$DIR = Get-Location
$DIR = $DIR.tostring()
$LOG_DIR = $DIR + "\log\"
$LOG_NAME = "AutoInvite.log"
$ERR_NAME = "AutoInvite.err"


$LOG_NAME, $ERR_NAME | ForEach-Object {
    $path = $LOG_DIR + $_ + $MAX_LOGS
    if([System.IO.File]::Exists($path)){
        Remove-Item $path -Force
    }
}

for ($i = ($MAX_LOGS - 1); $i -gt 0; $i--) {
    $LOG_NAME, $ERR_NAME | ForEach-Object {
        $path = $LOG_DIR + $_ + $i
        $newName = $_ + ($i + 1)
        if([System.IO.File]::Exists($path)){
            Rename-Item -Path $path -NewName $newName -Force
        }
    }
}

$LOG_NAME, $ERR_NAME | ForEach-Object {
    $path = $LOG_DIR + $_
    $newName = $_ + 1
    if([System.IO.File]::Exists($path)){
        Rename-Item -Path $path -NewName $newName -Force
    }
}

$file_script = $DIR + "\AutoInvite-Guests.ps1"
$file_stdout = $LOG_DIR + $LOG_NAME
$file_stderr = $LOG_DIR + $ERR_NAME

powershell -File $file_script -DIR $DIR *>$file_stdout