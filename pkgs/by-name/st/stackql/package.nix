{
  lib,
  fetchFromGitHub,
  buildGoModule,
  testers,
  stackql,
}:

buildGoModule rec {
  pname = "stackql";
  version = "0.8.175";

  src = fetchFromGitHub {
    owner = "stackql";
    repo = "stackql";
    rev = "v${version}";
    hash = "sha256-JA9vTmjNIXhvcdH9BPmtSD3W3VkytG+dYOtOJ+hFnsQ=";
  };

  vendorHash = "sha256-lACvTdzOZ5AnPqaw+uGMbO3HnjKU/dSVATgmrdYpWNE=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/stackql/stackql/internal/stackql/cmd.BuildMajorVersion=${builtins.elemAt (lib.splitVersion version) 0}"
    "-X github.com/stackql/stackql/internal/stackql/cmd.BuildMinorVersion=${builtins.elemAt (lib.splitVersion version) 1}"
    "-X github.com/stackql/stackql/internal/stackql/cmd.BuildPatchVersion=${builtins.elemAt (lib.splitVersion version) 2}"
    "-X github.com/stackql/stackql/internal/stackql/cmd.BuildDate=2024-05-15T07:51:52Z" # date of commit hash
    "-X stackql/internal/stackql/planbuilder.PlanCacheEnabled=true"
  ];

  __darwinAllowLocalNetworking = true;

  checkFlags = [ "--tags json1,sqleanal" ];

  passthru.tests.version = testers.testVersion {
    package = stackql;
    version = "v${version}";
  };

  meta = {
    homepage = "https://github.com/stackql/stackql";
    description = "Deploy, manage and query cloud resources and interact with APIs using SQL";
    mainProgram = "stackql";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ jonochang ];
  };
}
