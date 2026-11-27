{
  pkgs,
  preCommitGen,
}:
{
  inherit (preCommitGen) pre-commit-check;

  # Extract-and-derive logic of the paperless enrichment script, run against
  # the shipped extractor table with fixtures taken from real documents.
  paperless-enrich = pkgs.runCommand "paperless-enrich-self-test" { } ''
    cp ${./hosts/coltrane/paperless/paperless-enrich.py} paperless-enrich.py
    cp ${./hosts/coltrane/paperless/extractors.json} extractors.json
    ${pkgs.python3}/bin/python3 paperless-enrich.py --self-test
    touch $out
  '';
}
