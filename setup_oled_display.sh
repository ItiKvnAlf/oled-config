#!/bin/bash

# Variables
MIN_MAJOR_PYTHON_VERSION=3
MIN_MINOR_PYTHON_VERSION=7
VENV_DIR=venv  # Virtual environment directory
PI_USER=capstone
FULL_DIR="/home/$PI_USER/$VENV_DIR"

# Function to install pip
install_pip() {
    #This function installs pip if it is not already installed.
    if ! command -v pip3 &> /dev/null; then
        echo "Installing pip..."
        sudo apt-get install --upgrade -y python3-pip python3-setuptools
    else
        echo "pip is already installed."
    fi
}

# Function to set up raspi-config
set_up_raspi_config() {
    #This function sets up raspi-config, which enables various Raspberry Pi interfaces.
    echo "Enabling Raspberry Pi interfaces..."
    echo "Enabling I2C"
    sudo raspi-config nonint do_i2c 0
    echo "Enabling SPI"
    sudo raspi-config nonint do_spi 0
    echo "Enabling Serial"
    sudo raspi-config nonint do_serial_hw 0
    echo "Enabling SSH"
    sudo raspi-config nonint do_ssh 0
    echo "Enabling Camera"
    sudo raspi-config nonint do_camera 0
    echo "Disable raspi-config at Boot"
    sudo raspi-config nonint disable_raspi_config_at_boot 0
}

# Function to create and activate a virtual environment for DAUGHTER BOX
create_virtualenv() {
    #This function creates and activates a Python virtual environment.
    if [ ! -d "$FULL_DIR" ]; then
        echo "Creating virtual environment in $FULL_DIR..."
        python3 -m venv $FULL_DIR
    else
        echo "Virtual environment already exists in $FULL_DIR."
    fi

    # Activate the virtual environment
    source $FULL_DIR/bin/activate
    echo "Virtual environment activated."
}


# Function to install Blinka
install_blinka() {
    #This function installs Blinka, which is Adafruit's CircuitPython library.
    if ! python3 -c "import board" &> /dev/null; then
        echo "Installing Blinka and dependencies..."
        sudo apt-get install -y i2c-tools libgpiod-dev python3-libgpiod
        pip install RPi.GPIO
        pip install adafruit-blinka
    else
        echo "Blinka is already installed."
    fi
}

  () {
    #This function installs the libgpiod library.
    if ! python3 -c "import gpiod" &> /dev/null; then
        echo "Installing libgpiod..."
        pip install libgpiod
    else
        echo "libgpiod is already installed."
    fi
}

# Function to install Adafruit CircuitPython SSD1306
install_circuitpython_ssd1306() {
    #This function installs the Adafruit CircuitPython SSD1306 library.
    if ! python3 -c "import adafruit_ssd1306" &> /dev/null; then
        echo "Installing Adafruit CircuitPython SSD1306..."
        pip install adafruit-circuitpython-ssd1306
    else
        echo "Adafruit CircuitPython SSD1306 is already installed."
    fi
}

# Function to install Pillow (Pil)
install_pillow() {
    #This function installs the Pillow library.
    if ! python3 -c "import PIL" &> /dev/null; then
        echo "Installing Pil..."
        pip install pillow
    else
        echo "Pil is already installed."
    fi
}

# Function to install Psutil
install_psutil() {
    #This function installs the Psutil library.
    if ! python3 -c "import psutil" &> /dev/null; then
        echo "Installing Psutil..."
        pip install psutil
    else
        echo "Psutil is already installed."
    fi
}

# Install pip
install_pip

# Set up raspi-config
set_up_raspi_config

# Create and activate a virtual environment for DAUGHTER BOX
create_virtualenv

# Install Blinka
install_blinka

# Install Pil
install_pillow

# Install Psutil
install_psutil

# Install Adafruit CircuitPython SSD1306
install_circuitpython_ssd1306

echo "Configuration complete."
echo "Now proceeding to the service configuration for the OLED display."

# Prompt for the username and mode
read -p "Enter the username of the system (e.g., pi): " USERNAME
read -p "Enter the mode of the device (mh/db): " MODE

# Validate the selected mode
if [[ "$MODE" != "mh" && "$MODE" != "db" ]]; then
    echo "Invalid mode. Please enter 'mh' for Mother Hub or 'db' for Daughter Box."
    exit 1
fi

# Define service names and paths
SERVICE_MH="oled-motherhub"
SERVICE_DB="oled-daughterbox"
PYTHON_SCRIPT_MH="/home/$USERNAME/$SERVICE_MH/main.py"
PYTHON_SCRIPT_DB="/home/$USERNAME/$SERVICE_DB/main.py"
PYTHON_PATH=$(which python3)
SERVICE_FILE_MH="/etc/systemd/system/$SERVICE_MH.service"
SERVICE_FILE_DB="/etc/systemd/system/$SERVICE_DB.service"

# Function to create a service file
create_service_file() {
    local SERVICE_NAME=$1
    local PYTHON_SCRIPT=$2
    local SERVICE_FILE=$3

    if [ ! -f "$PYTHON_SCRIPT" ]; then
        echo "Python script $PYTHON_SCRIPT not found. Make sure the script exists and try again."
        exit 1
    fi

    echo "Creating the service file at $SERVICE_FILE..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=$SERVICE_NAME - Service for OLED Display
After=network-online.target multi-user.target
Wants=network-online.target

[Service]
ExecStart=/bin/bash -c '$(realpath $FULL_DIR/bin/activate) python3 $PYTHON_SCRIPT'
WorkingDirectory=$(dirname $PYTHON_SCRIPT)

[Install]
WantedBy=multi-user.target
EOL

    sudo chmod 644 $SERVICE_FILE
    sudo chown root:root $SERVICE_FILE
    echo "Service file $SERVICE_FILE created successfully."
}

# Create both service files
create_service_file "$SERVICE_MH" "$PYTHON_SCRIPT_MH" "$SERVICE_FILE_MH"
create_service_file "$SERVICE_DB" "$PYTHON_SCRIPT_DB" "$SERVICE_FILE_DB"

# Reload systemd to recognize new services
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Disable both services initially
echo "Disabling both services..."
sudo systemctl disable $SERVICE_MH --now
sudo systemctl disable $SERVICE_DB --now

# Set the selected mode
if [[ "$MODE" == "db" ]]; then
  SELECTED_SERVICE="oled-daughterbox"
elif [[ "$MODE" == "mh" ]]; then
  SELECTED_SERVICE="oled-motherhub"
fi

echo "Enabling and starting $SELECTED_SERVICE service..."
sudo systemctl enable $SELECTED_SERVICE --now

echo "Service configuration completed successfully."

# Reboot the system
read -p "Do you want to reboot the system now? [Y/n]: " user_choice
user_choice=${user_choice:-Y}
if [[ "$user_choice" =~ ^[Yy]$ ]]; then
    echo "Rebooting the system..."
    sudo reboot
else
    echo "Please reboot the system to apply the changes."
fi
