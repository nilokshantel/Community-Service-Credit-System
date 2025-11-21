# 🌟 Community Service Credit System

A blockchain-based smart contract system for tracking and validating community service contributions using soulbound tokens on the Stacks network.

## 📖 Overview

The Community Service Credit System solves the problem of undervalued and hard-to-verify volunteer contributions by creating a permanent, verifiable record of community service. Volunteers receive non-transferable (soulbound) tokens that accumulate into a reputation score, serving as proof of their service history.

## ✨ Key Features

### 🏛️ **Organization Management**
- Register community organizations
- Assign organization leads for validation
- Track organization statistics
- Transfer leadership capabilities

### 👥 **Volunteer System**
- Submit service contributions with descriptions
- Accumulate non-transferable service credits
- Build reputation scores over time
- Track service history across organizations

### ✅ **Validation Process**
- Organization leads validate contributions
- Prevents self-validation
- Timestamp validation with block heights
- Automatic credit awarding upon validation

### 🏆 **Reputation System**
- **Beginner**: < 50 points
- **Bronze**: 50-199 points  
- **Silver**: 200-499 points
- **Gold**: 500+ points
- Bonus points for longevity and consistency

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation
```bash
git clone https://github.com/yourusername/Community-Service-Credit-System
cd Community-Service-Credit-System
clarinet check
```

## 📋 Usage Instructions

### 🏢 For Organizations

#### Register Your Organization
```clarity
(contract-call? .Community-Service-Credit-System register-organization "Local Food Bank")
```

#### Validate Volunteer Contributions
```clarity
(contract-call? .Community-Service-Credit-System validate-contribution u1)
```

#### Transfer Leadership
```clarity
(contract-call? .Community-Service-Credit-System transfer-organization-leadership u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### 🙋 For Volunteers

#### Submit Your Service Contribution
```clarity
(contract-call? .Community-Service-Credit-System submit-contribution u1 u5 "Helped serve meals to 50 families")
```

#### Check Your Profile
```clarity
(contract-call? .Community-Service-Credit-System get-volunteer-profile 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### Verify Your Credits for Recognition Programs
```clarity
(contract-call? .Community-Service-Credit-System verify-volunteer-credits 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u25)
```

### 🔍 Query Functions

#### Get Organization Information
```clarity
(contract-call? .Community-Service-Credit-System get-organization-info u1)
```

#### View Contribution Details
```clarity
(contract-call? .Community-Service-Credit-System get-contribution-details u1)
```

#### Check Volunteer-Organization History
```clarity
(contract-call? .Community-Service-Credit-System get-volunteer-organization-history 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1)
```

#### Get System Statistics
```clarity
(contract-call? .Community-Service-Credit-System get-total-system-stats)
```

#### Check Reputation Tier
```clarity
(contract-call? .Community-Service-Credit-System get-reputation-tier 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🔄 Workflow Example

1. **🏛️ Organization Setup**
   ```clarity
   ;; Food Bank registers
   (contract-call? .Community-Service-Credit-System register-organization "Community Food Bank")
   ;; Returns organization-id: u1
   ```

2. **🙋 Volunteer Contribution**
   ```clarity
   ;; Volunteer submits 4 hours of service
   (contract-call? .Community-Service-Credit-System submit-contribution u1 u4 "Sorted and packed food donations")
   ;; Returns contribution-id: u1
   ```

3. **✅ Lead Validation**
   ```clarity
   ;; Organization lead validates the contribution
   (contract-call? .Community-Service-Credit-System validate-contribution u1)
   ;; Automatically awards 4 credits to volunteer
   ```

4. **🏆 Recognition**
   ```clarity
   ;; Check volunteer's reputation tier
   (contract-call? .Community-Service-Credit-System get-reputation-tier 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
   ;; Returns current tier based on accumulated points
   ```

## 🎯 Use Cases

### 🏫 **Educational Institutions**
- Track student community service hours
- Verify service for graduation requirements
- Recognize outstanding civic engagement

### 🏢 **Employers**
- Consider volunteer history in hiring decisions
- Reward employees for community involvement
- Build corporate social responsibility metrics

### 🏛️ **Government Programs**
- Verify volunteer contributions for awards
- Track community engagement initiatives
- Support civic recognition programs

### 🤝 **Nonprofit Organizations**
- Build volunteer databases
- Create volunteer appreciation programs
- Track organizational impact metrics

## 🔐 Security Features

- **Soulbound Tokens**: Credits cannot be transferred between accounts
- **Validation Required**: All credits must be validated by organization leads
- **Self-Validation Prevention**: Volunteers cannot validate their own contributions
- **Immutable Records**: All contributions are permanently recorded on-chain
- **Access Control**: Only organization leads can validate contributions

## 📊 Data Structure

### Volunteer Profile
- Total credits earned
- Total service hours
- Number of contributions
- Reputation score
- First contribution timestamp

### Organization Data
- Organization name and lead
- Total validated hours
- Number of volunteers served
- Active status

### Contribution Records
- Volunteer and organization details
- Service hours and description
- Submission and validation timestamps
- Validator information

## 🛠️ Development

### Running Tests
```bash
npm install
npm test
```

### Contract Deployment
```bash
clarinet deployments generate --devnet
clarinet deployments apply --devnet
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and ensure they pass
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🌍 Impact

The Community Service Credit System builds verifiable volunteering records, motivates civic engagement, and strengthens trust in community projects by providing:

- **🔍 Transparency**: All service records are publicly verifiable
- **🏆 Recognition**: Volunteers receive recognition for their contributions
- **📈 Motivation**: Reputation system encourages continued engagement
- **🤝 Trust**: Validation system ensures accurate record-keeping
- **🌟 Impact**: Measurable community service tracking

---

*Built with ❤️ for stronger communities using Stacks blockchain technology*
