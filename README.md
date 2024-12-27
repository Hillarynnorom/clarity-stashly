# Stashly
A decentralized savings application with automated compounding built on Stacks.

## Features
- Deposit STX tokens into savings vault
- Automatic compounding of rewards
- Withdrawal with timelock options
- View total savings and earned interest
- Emergency withdrawal with penalty

## Architecture
The contract implements a savings vault where users can deposit STX tokens. The deposits earn compound interest based on the time period and amount staked. Interest is calculated and compounded automatically at regular intervals.