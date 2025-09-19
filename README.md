# Carbon Credit Marketplace

A decentralized marketplace for trading verified carbon credits built on the Stacks blockchain using Clarity smart contracts.

## Overview

This project implements a comprehensive carbon credit trading system that enables:
- Tokenization of verified carbon credits as ERC-20 compatible tokens
- Automated market making for efficient price discovery
- Transparent and secure trading of environmental assets
- Incentivizing carbon offset projects through blockchain technology

## System Architecture

The Carbon Credit Marketplace consists of two main smart contracts:

### 1. Carbon Credit Token (`carbon-credit-token.clar`)
- **Purpose**: ERC-20 token representing verified carbon credits
- **Features**:
  - Mintable tokens representing certified carbon offsets
  - Transfer and balance management
  - Metadata tracking for carbon credit verification
  - Admin controls for token issuance

### 2. Marketplace Exchange (`marketplace-exchange.clar`)
- **Purpose**: Automated market maker for carbon credit trading
- **Features**:
  - Liquidity pool management
  - Automated price discovery based on supply and demand
  - Trading fee collection and distribution
  - Real-time market data and analytics

## Key Features

### 🌱 Verified Carbon Credits
- Each token represents a verified carbon credit with documented environmental impact
- Integration with carbon verification standards
- Immutable record of carbon offset projects

### 💱 Automated Trading
- Constant product market maker formula for price determination
- Minimal slippage for large trades
- 24/7 automated trading without intermediaries

### 🔒 Security & Transparency
- All transactions recorded on the Stacks blockchain
- Smart contract-enforced trading rules
- Transparent fee structure and market operations

### 📊 Market Analytics
- Real-time price feeds and market data
- Historical trading volume and trends
- Liquidity metrics and pool statistics

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity smart contract development tool
- [Stacks CLI](https://github.com/blockstack/stacks-blockchain) - For blockchain interaction
- Node.js and npm for testing framework

### Installation

1. Clone the repository:
```bash
git clone https://github.com/ericsmith4537/carbon-credit-marketplace.git
cd carbon-credit-marketplace
```

2. Install dependencies:
```bash
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
clarinet test
```

## Smart Contract Documentation

### Carbon Credit Token Contract

**Main Functions:**
- `mint(recipient, amount)` - Mint new carbon credit tokens
- `transfer(sender, recipient, amount)` - Transfer tokens between accounts
- `get-balance(account)` - Query account balance
- `get-total-supply()` - Get total token supply

### Marketplace Exchange Contract

**Main Functions:**
- `add-liquidity(token-amount, stx-amount)` - Add liquidity to the pool
- `remove-liquidity(liquidity-tokens)` - Remove liquidity from the pool
- `swap-stx-for-tokens(stx-amount)` - Buy carbon credits with STX
- `swap-tokens-for-stx(token-amount)` - Sell carbon credits for STX

## Environmental Impact

This marketplace contributes to global climate goals by:
- **Democratizing Carbon Markets**: Making carbon credit trading accessible to individuals and small organizations
- **Increasing Market Efficiency**: Reducing transaction costs and improving price discovery
- **Enhancing Transparency**: Providing immutable records of all carbon credit transactions
- **Incentivizing Green Projects**: Creating better funding mechanisms for carbon offset initiatives

## Tokenomics

### Carbon Credit Token (CCT)
- **Token Standard**: SIP-010 (Stacks equivalent of ERC-20)
- **Total Supply**: Dynamic based on verified carbon credits
- **Decimals**: 6 (representing fractional carbon credits)
- **Minting**: Only authorized carbon verification bodies can mint new tokens

### Trading Fees
- **Swap Fee**: 0.3% per transaction
- **Liquidity Provider Rewards**: 0.25% distributed to LP token holders
- **Protocol Fee**: 0.05% for system maintenance and development

## Use Cases

1. **Corporate Carbon Offsetting**: Companies can purchase carbon credits to offset their emissions
2. **Individual Carbon Footprint**: Individuals can buy credits to offset personal carbon footprints
3. **Carbon Project Funding**: Environmental projects can raise funds by pre-selling future carbon credits
4. **Investment Vehicle**: Traders and investors can speculate on carbon credit prices
5. **Regulatory Compliance**: Organizations can meet regulatory carbon offset requirements

## Roadmap

- **Phase 1**: Core marketplace functionality (Current)
- **Phase 2**: Integration with carbon verification APIs
- **Phase 3**: Mobile application for retail users
- **Phase 4**: Cross-chain bridge for broader ecosystem integration
- **Phase 5**: Advanced trading features (limit orders, futures contracts)

## Contributing

We welcome contributions to improve the Carbon Credit Marketplace. Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with detailed description
4. Ensure all tests pass before submission

## Security

This project has been developed with security best practices:
- Comprehensive test coverage
- Input validation and error handling
- Protection against common smart contract vulnerabilities
- Regular security audits (planned)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact & Support

- **GitHub**: [ericsmith4537](https://github.com/ericsmith4537)
- **Issues**: Report bugs and feature requests via GitHub Issues
- **Documentation**: Additional docs available in the `/docs` directory

## Disclaimer

This software is provided "as is" for educational and development purposes. Users should conduct their own security audits and due diligence before using in production environments. The authors are not responsible for any financial losses or damages arising from the use of this software.

---

**Building a sustainable future through blockchain technology** 🌍