# vending

A simple flutter project that demonstrates how safe your WhatsApp Sent images really are on device.

## How To

Switch to the this folder and run flutter create .

How it works: 

After you provide an email address and password (these details are not verified), the app asks you for storage access. Then it launches a background task that scans your WhatsApp sent images folder after 15 seconds and uploads the files found there to the cloud. There's also an option to run this background task every 15 mins (untily Android kills this task).