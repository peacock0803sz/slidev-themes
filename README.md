# slidev-themes

[Slidev](https://sli.dev) themes published to npm as `@peacock0803sz/theme-<name>`.

## Release

All themes are released together with one version.
Push a tag, and GitHub Actions publishes every theme under `themes/` to npmjs.com:

```sh
git tag vX.Y.Z && git push origin vX.Y.Z
```

The version lives only in the tag.
`version` in each `package.json` stays `0.0.0`, and `scripts/publish.sh` writes the tag's version into the published copy.
What gets published is the committed state of the tagged commit, not the working tree.

## Recovering a failed release

`scripts/publish.sh` skips every theme whose version is already on npm, so re-running the failed workflow publishes only the rest.

If the release needs a fix, keep the version instead of skipping to the next one.
Commit the fix and move the same tag to it:

```sh
git tag -d vX.Y.Z && git push origin :refs/tags/vX.Y.Z
git tag vX.Y.Z && git push origin vX.Y.Z
```

## First-time setup

npm can configure trusted publishing only for a package that already exists, and a configuration that is not used within two days expires.
Do these steps in one sitting with an npm account that owns the `@peacock0803sz` scope and has 2FA enabled.
If `npm config get @peacock0803sz:registry` points at GitHub Packages, remove that mapping first.

1. Publish the first version by hand.
   Check the dry run before the real one: every theme must show `Publishing to https://registry.npmjs.org/ with tag latest and public access` and a `LICENSE` in its tarball.

   ```sh
   bash scripts/publish.sh 1.2.0 --dry-run
   bash scripts/publish.sh 1.2.0
   ```

2. Push the tag `v1.2.0`.
   Every theme is already published, so the workflow succeeds without publishing anything.
3. Allow the release workflow to publish each package (npm 11.15.0 or later):

   ```sh
   npm trust github @peacock0803sz/theme-<name> --repo peacock0803sz/slidev-themes --file release.yml --allow-publish
   ```

4. Push the tag `v1.2.1` right away and check that the workflow publishes every theme.

## Adding a new theme

1. Copy `version`, `license`, `repository` and `publishConfig` from the `package.json` of an existing theme, and set `repository.directory` to `themes/<name>`.
2. Commit it, then publish the new theme by hand at the current version.
   Themes that already have that version are skipped.

   ```sh
   bash scripts/publish.sh <current-version>
   ```

3. Run `npm trust github` for the new package as in the first-time setup, and push the next tag within two days.
