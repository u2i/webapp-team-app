# Pull Request - webapp-team

## 📋 Change Summary
<!-- Provide a brief description of the changes -->

## 🎯 Type of Change
- [ ] 🐛 Bug fix (non-breaking change that fixes an issue)
- [ ] ✨ New feature (non-breaking change that adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🔧 Infrastructure change
- [ ] 🔒 Security update
- [ ] 📦 Dependency update

## 🔒 Compliance Checklist

### ISO 27001 Requirements
- [ ] **A.12.1.2** Change management process followed
- [ ] **A.9.4.1** Access controls maintained
- [ ] **A.12.4.1** Changes are logged and auditable
- [ ] **A.12.6.1** Security vulnerabilities addressed

### SOC 2 Type II Requirements  
- [ ] **CC8.1** Change control procedures followed
- [ ] **CC6.1** Logical access controls maintained
- [ ] **CC6.6** Audit trail maintained
- [ ] **CC7.2** System monitoring considerations addressed

### GDPR Compliance (EU/Belgium)
- [ ] **Art. 25** Data protection by design maintained
- [ ] **Art. 32** Security measures appropriate for processing
- [ ] **Data residency** EU/Belgium compliance maintained
- [ ] **Privacy** No new personal data processing introduced

## 🔍 Testing Checklist
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Security scan results reviewed
- [ ] Container vulnerability scan clean
- [ ] Compliance validation passes
- [ ] Non-production deployment tested

## 🚀 Deployment Checklist
- [ ] Resource limits defined for all containers
- [ ] Security contexts properly configured
- [ ] Network policies updated if needed
- [ ] Secrets managed via Secret Manager
- [ ] Compliance labels present on all resources
- [ ] Documentation updated

## 🔐 Security Considerations
- [ ] No secrets or credentials in code
- [ ] Principle of least privilege maintained
- [ ] Security contexts follow restricted pod security standards
- [ ] Network policies enforce proper isolation
- [ ] Container images from approved registries only

## 📊 Production Impact Assessment

### Risk Level
- [ ] 🟢 Low (minor changes, no user impact)
- [ ] 🟡 Medium (moderate changes, minimal user impact)
- [ ] 🔴 High (significant changes, user-facing impact)

### Production Readiness
- [ ] Non-production testing completed
- [ ] Performance impact assessed
- [ ] Rollback plan documented
- [ ] Monitoring and alerting considerations addressed
- [ ] Security team approval obtained (if required)

## 📝 Additional Notes
<!-- Any additional context, concerns, or considerations -->

## 🔗 Related Issues
<!-- Link any related GitHub issues -->
Closes #

---

### For Production Changes Only
**⚠️ If this change affects production, additional approvals are required:**

- [ ] **Security team review** - @security-team 
- [ ] **Platform team review** - @platform-team
- [ ] **Compliance verification** - @compliance-team
- [ ] **Production deployment approval** obtained via issue

**Production deployment process:**
1. Merge this PR to deploy to non-production
2. Test thoroughly in non-production environment  
3. Create production promotion issue for security approval
4. Use production promotion workflow after approval