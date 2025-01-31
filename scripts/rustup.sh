#!/usr/bin/env bash

set -e

TOOLCHAIN=${TOOLCHAIN:-$(date +%Y-%m-%d)}

case $1 in
    "prepare")
        echo "=> Installing new nightly"
        rustup toolchain install --profile minimal "nightly-${TOOLCHAIN}" # Sanity check to see if the nightly exists
        sed -i "s/\"nightly-.*\"/\"nightly-${TOOLCHAIN}\"/" rust-toolchain
        rustup component add rustfmt || true

        echo "=> Uninstalling all old nightlies"
        for nightly in $(rustup toolchain list | grep nightly | grep -v "$TOOLCHAIN" | grep -v nightly-x86_64); do
            rustup toolchain uninstall "$nightly"
        done

        ./clean_all.sh

        ./y.rs prepare

        (cd download/sysroot && cargo update && cargo fetch && cp Cargo.lock ../../build_sysroot/)
        ;;
    "commit")
        git add rust-toolchain build_sysroot/Cargo.lock
        git commit -m "Rustup to $(rustc -V)"
        ;;
    "push")
        cg_clif=$(pwd)
        pushd ../rust
        git pull origin master
        branch=sync_cg_clif-$(date +%Y-%m-%d)
        git checkout -b "$branch"
        git subtree pull --prefix=compiler/rustc_codegen_cranelift/ https://github.com/bjorn3/rustc_codegen_cranelift.git master
        git push -u my "$branch"

        # immediately merge the merge commit into cg_clif to prevent merge conflicts when syncing
        # from rust-lang/rust later
        git subtree push --prefix=compiler/rustc_codegen_cranelift/ "$cg_clif" sync_from_rust
        popd
        git merge sync_from_rust
	;;
    "pull")
        RUST_VERS=$(curl "https://static.rust-lang.org/dist/$TOOLCHAIN/channel-rust-nightly-git-commit-hash.txt")
        echo "Pulling $RUST_VERS ($TOOLCHAIN)"

        cg_clif=$(pwd)
        pushd ../rust
        git fetch origin master
        git checkout "$RUST_VERS"
        git subtree push --prefix=compiler/rustc_codegen_cranelift/ "$cg_clif" sync_from_rust
        popd
        git merge sync_from_rust -m "Sync from rust $RUST_VERS"
        git branch -d sync_from_rust
        ;;
    *)
        echo "Unknown command '$1'"
        echo "Usage: ./rustup.sh prepare|commit"
        ;;
esac
