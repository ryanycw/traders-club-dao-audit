# Traders Club DAO Audit
An audit report for the well-known alpha group - Taiwan Traders Club DAO's NFT

---

### Issues Summary

The scope of this audit: `contracts/TradersClubDAOERC721A.sol` </br>
All the details of the issues were commented in the corresponding lines. </br>
Recommendations were implemented in `contracts/TradersClubDAO.sol` </br>

| Issue No. | Issue Category | Apprearance | Severity |
| --------- | -------------- | ----------- | -------- |
| 1 | Unessecary Implementation | L12, L15, L37, L56:57, L61, L64, L71, L102, L131, L156 | Low |
| 2 | Unuse Variables | L22, L26 | Low |
| 3 | Inconsistant Naming / Coding Style | L31, L148 | Low |
| 4 | Suggesting EDCSA | L39, L59, L69 | Medium |
| 5 | Withdraw with Amount | L139 | Medium |

Ordered with the line # of the first appearance
