# PowerShell script to create and lock a file

# Specify the path and name of the file
$filePath = "C:\Path\To\Your\File\lockedfile.txt"

# Create the file if it doesn't exist
if (-not (Test-Path $filePath)) {
    New-Item -Path $filePath -ItemType File
}

# Open the file for reading and writing
$fileStream = [System.IO.File]::Open($filePath, 'Open', 'ReadWrite', 'None')

# The file is now locked and cannot be deleted until the lock is released
Write-Host "The file is now locked and cannot be deleted until the lock is released."

# To keep the script running and the file locked, uncomment the line below
# Wait-Event -Timeout (60 * 60) # Keep the file locked for 1 hour

# To release the lock, close the file stream
# $fileStream.Close()