# Batch7zArchiver

Batch Script that automates compressing every folders in a
script directory using 7-Zip

## Features

- **Configurable compression level** — tune the speed/size trade-off
- **Optional password protection** — set a password to encrypt folder/s
- **Integrity verification** — tested every archive
- **Safe deletion** — source folders are only deleted after their archive
  passes verification
- **Dry run mode** — preview exactly which folders would be compressed and
  removed
- **Detailed summaries** — a compression summary and a verification/removal
  summary are printed at the end, listing any failures by folder name

## Requirements

- [7-Zip](https://www.7-zip.org/)

## Usage

- Place `Batch7zArchiver.bat` in the parent directory containing the
  folders you want to compress
