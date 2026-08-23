# Fleet media API keys — single source of truth.
#
# These keys are seeded into each service's config.xml at startup (idempotent:
# only written when the file lacks the key). Declaring them here means the
# *arr apps can be wired together automatically (prowlarr-sync) and homarr
# integrations configured without copy-pasting keys between UIs.
#
# Treat this file as sensitive: it grants full API access to each app.
{
  prowlarr = "aef3d89a62c5b141289e16adcd63f56aeab40a2ec5f72864b7b3aff203de5e41";
  sonarr = "b3bf8f5a17f7bb30318562531ff15d114f9463f2f56cd3bbbbf9213cb54deb04";
  radarr = "7599202763a2769e0424a8c2604a869da82823bf2f98e07a49ebabc63541fd02";
  readarr = "237b0a5001ceb946651d756b4d090eda15824963842a0187507adcd2f36aace3";
  lidarr = "788208ca8ea641eab0771b1947e202d417e9f69ceae776664395ac2ddd984574";
}
