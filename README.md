# AetherStore
A decentralized e-commerce marketplace built on Stacks blockchain using Clarity smart contracts.

## Features
- List products for sale
- Purchase products using STX tokens
- Manage product inventory
- Review system for buyers
- Escrow system for secure transactions
- Store reputation tracking

## Setup and Installation
1. Clone the repository
2. Install Clarinet (if not already installed)
3. Run `clarinet check` to verify contracts
4. Run `clarinet test` to execute test suite

## Usage Examples
```clarity
;; List a new product
(contract-call? .aether-store list-product "iPhone 13" u1000000 u10 "New iPhone" 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Purchase a product
(contract-call? .aether-store purchase-product u1 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)

;; Leave a review
(contract-call? .aether-store leave-review u1 u5 "Great product!")
```

## Dependencies
- Clarity language
- Clarinet for testing and deployment
- STX token for transactions
