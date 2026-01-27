# Contributing

Thanks for choosing to contribute!

The following are a set of guidelines to follow when contributing to this project.

## Code Of Conduct

This project adheres to the Adobe [code of conduct](../CODE_OF_CONDUCT.md). By participating,
you are expected to uphold this code. Please report unacceptable behavior to
[Grp-opensourceoffice@adobe.com](mailto:Grp-opensourceoffice@adobe.com).

## Have A Question?

Start by filing an issue. The existing committers on this project work to reach
consensus around project direction and issue solutions within issue threads
(when appropriate).

## Contributor License Agreement

All third-party contributions to this project must be accompanied by a signed contributor
license agreement. This gives Adobe permission to redistribute your contributions
as part of the project. [Sign our CLA](https://opensource.adobe.com/cla.html). You
only need to submit an Adobe CLA one time, so if you have submitted one previously,
you are good to go!

## Code Reviews

All submissions should come in the form of pull requests and need to be reviewed
by project committers. Read [GitHub's pull request documentation](https://help.github.com/articles/about-pull-requests/)
for more information on sending pull requests.

Lastly, please follow the [pull request template](PULL_REQUEST_TEMPLATE.md) when
submitting a pull request!

## From Contributor To Committer

We love contributions from our community! If you'd like to go a step beyond contributor
and become a committer with full write access and a say in the project, you must
be invited to the project. The existing committers employ an internal nomination
process that must reach lazy consensus (silence is approval) before invitations
are issued. If you feel you are qualified and want to get more deeply involved,
feel free to reach out to existing committers to have a conversation about that.

## Security Issues

Security issues shouldn't be reported on this issue tracker. Instead, [file an issue to our security experts](https://helpx.adobe.com/security/alertus.html).

---

## Development Workflow

### Getting Started

1. **Fork the repository** to your GitHub account
2. **Clone your fork** locally:
   ```bash
   git clone git@github.com:YOUR_USERNAME/aca-mobile-sdk-ios-extension.git
   cd aca-mobile-sdk-ios-extension
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream git@github.com:adobe/aca-mobile-sdk-ios-extension.git
   ```
4. **Install dependencies**:
   ```bash
   make pod-install
   ```

### Making Changes

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/my-feature main
   ```

2. **Make your changes** following our coding standards:
   - Follow Swift style guide
   - Add unit tests for new code
   - Update documentation as needed
   - Run SwiftLint: `make lint`
   - Fix any linting issues: `make lint-autocorrect`

3. **Test your changes**:
   ```bash
   make test                    # Run all tests
   make unit-test-ios          # iOS tests only
   make functional-test-ios    # Functional tests only
   ```

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat: Add new feature"
   ```
   
   Follow [Conventional Commits](https://www.conventionalcommits.org/) format:
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation changes
   - `test:` Test additions/changes
   - `refactor:` Code refactoring
   - `perf:` Performance improvements
   - `chore:` Maintenance tasks

5. **Push to your fork**:
   ```bash
   git push origin feature/my-feature
   ```

6. **Open a Pull Request** to `adobe/aca-mobile-sdk-ios-extension:main`

### Pull Request Requirements

Your PR must meet these requirements to be merged:

- [ ] All tests passing (CI checks green)
- [ ] Code coverage maintained or improved
- [ ] SwiftLint checks passing
- [ ] Documentation updated if needed
- [ ] CHANGELOG.md updated (if applicable)
- [ ] Reviewed and approved by at least one maintainer

---

## Release Process

### Release Types

We follow semantic versioning with beta and release candidate stages:

| Type | Version Format | Example | Purpose |
|------|---------------|---------|---------|
| **Beta** | `X.Y.Z-beta.N` | `1.0.0-beta.1` | Early testing with select users |
| **Release Candidate** | `X.Y.Z-rc.N` | `1.0.0-rc.1` | Final validation before GA |
| **General Availability** | `X.Y.Z` | `1.0.0` | Production-ready release |
| **Patch** | `X.Y.Z` | `1.0.1` | Bug fixes only |
| **Minor** | `X.Y.0` | `1.1.0` | New features, backward compatible |
| **Major** | `X.0.0` | `2.0.0` | Breaking changes |

### Release Workflow (Automated)

Releases are **fully automated** via GitHub Actions when you push a version tag:

#### 1. Prepare Release

```bash
# Update version, run tests, build artifacts
./prepare-release.sh 1.0.0-beta.1

# Review changes
git diff

# Commit changes
git add .
git commit -m "Prepare release 1.0.0-beta.1"
```

#### 2. Push to Main

```bash
git push origin main
```

#### 3. Create and Push Tag

```bash
# Create annotated tag
git tag -a v1.0.0-beta.1 -m "Release 1.0.0-beta.1

New Features:
- Feature 1
- Feature 2

Bug Fixes:
- Fix 1
- Fix 2
"

# Push tag (triggers automated release)
git push origin v1.0.0-beta.1
```

#### 4. Automated Release (GitHub Actions)

When you push a version tag, the release workflow automatically:

✅ **Validates** the release:
- Verifies tag format (`v1.0.0`, `v1.0.0-beta.1`, `v1.0.0-rc.1`)
- Checks version consistency (code matches tag)
- Runs all tests
- Runs SwiftLint
- Builds XCFramework

✅ **Creates GitHub Release**:
- Extracts release notes from CHANGELOG.md
- Uploads XCFramework artifact
- Marks as pre-release (for beta/RC)

✅ **Publishes to CocoaPods** (for RC and GA only):
- Validates podspec
- Publishes to CocoaPods trunk

✅ **Notifies team**:
- Posts release summary
- Lists next steps

### Release Schedule

**Beta → RC → GA Flow:**

```
Week 1: Beta Release
  └─ v1.0.0-beta.1 (automated release)
  └─ Customer testing begins

Weeks 2-4: Beta Iterations
  └─ v1.0.0-beta.2, beta.3 as needed
  └─ Bug fixes based on feedback

Week 5: Release Candidate
  └─ v1.0.0-rc.1 (automated release)
  └─ Final validation

Week 6-7: Final Testing
  └─ v1.0.0-rc.2 if needed (critical fixes only)
  └─ Documentation finalization

Week 8: General Availability
  └─ v1.0.0 (automated release + CocoaPods)
  └─ Production-ready 🚀
```

### Hotfix Process

For urgent production fixes:

1. Create hotfix branch from the affected version tag:
   ```bash
   git checkout -b hotfix/1.0.1 v1.0.0
   ```

2. Make the fix and test thoroughly

3. Update version:
   ```bash
   ./prepare-release.sh 1.0.1
   ```

4. Push and tag:
   ```bash
   git push origin hotfix/1.0.1
   git tag -a v1.0.1 -m "Hotfix 1.0.1: Fix critical issue"
   git push origin v1.0.1
   ```

5. Automated release workflow handles the rest

6. Merge hotfix back to main:
   ```bash
   git checkout main
   git merge hotfix/1.0.1
   git push origin main
   ```

---

## Coding Standards

### Swift Style Guide

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint for consistency (`.swiftlint.yml` configured)
- Write clear, self-documenting code
- Add documentation comments for public APIs

### Testing Requirements

- **Minimum 80% code coverage** for new code
- Unit tests for all public APIs
- Integration tests for critical flows
- Mock external dependencies
- Test both success and failure paths

### Documentation

- Update README.md for user-facing changes
- Add API documentation comments (`///`)
- Update CHANGELOG.md for each release
- Include code examples for new features

---

## Getting Help

- **Questions?** Open a [GitHub Discussion](https://github.com/adobe/aca-mobile-sdk-ios-extension/discussions)
- **Bug Report?** Open an [Issue](https://github.com/adobe/aca-mobile-sdk-ios-extension/issues)
- **Feature Request?** Open an [Issue](https://github.com/adobe/aca-mobile-sdk-ios-extension/issues)

---

## Maintainer Notes

### Creating a Release (Maintainers Only)

As a maintainer, here's the complete release process:

1. **Ensure main is stable** and all PRs merged
2. **Run prepare-release script** locally to update versions
3. **Review CHANGELOG.md** and add release date
4. **Commit and push** version changes to main
5. **Create and push tag** (triggers automated release)
6. **Monitor GitHub Actions** for successful release
7. **Verify release** on GitHub and CocoaPods (for GA/RC)
8. **Announce release** (Slack, blog, etc.)
9. **Update documentation** sites if needed

### Required GitHub Secrets

For automated releases to work, configure these secrets:

- `COCOAPODS_TRUNK_TOKEN` - CocoaPods publishing token
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

---

## License

By contributing to this project, you agree that your contributions will be licensed under the Apache License 2.0.

