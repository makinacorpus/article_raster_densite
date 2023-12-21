DROP TABLE IF EXISTS belgium_raster_coverage;
CREATE UNLOGGED TABLE belgium_raster_coverage AS
    SELECT
        ST_AddBand(
            ST_MakeEmptyCoverage(
                    tilewidth=>500,
                    tileheight=>500,  -- Tile sizes (in pixels)
                    width=>3425,
                    height=>2753, -- Raster layer size (ie the size of your region)
                    upperleftx=>470093.9757537913,
                    upperlefty=>777595.0619878168, -- Raster origin
                    scalex=>100,
                    scaley=>-100,  -- Pixel size
                    skewx=> 0.,
                    skewy=>0., -- No skewing
                     srid=>3812),
            '32BUI' :: TEXT, 0) as raster;

-- add new auto incremented field
ALTER TABLE  belgium_raster_coverage ADD id bigserial primary key;

SELECT AddRasterConstraints('belgium_raster_coverage'::name, 'raster'::name);

CREATE INDEX belgium__rast_envelope_idx ON belgium_raster_coverage USING gist( ST_Envelope(raster) );

ANALYZE belgium_raster_coverage;
