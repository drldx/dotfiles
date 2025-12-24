#!/bin/bash

IFACE="wlo1"

RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
TX1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
sleep 1
RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
TX2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)

RXBPS=$(((RX2 - RX1) / 1024))
TXBPS=$(((TX2 - TX1) / 1024))

echo " ${RXBPS}k/s  ${TXBPS}k/s"
