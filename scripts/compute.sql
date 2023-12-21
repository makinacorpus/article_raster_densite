CREATE OR REPLACE FUNCTION compute_raster(raster_id bigint) RETURNS void LANGUAGE SQL VOLATILE AS
    $$
    WITH metadata AS (
        -- this CTE fetches the metada FROM a raster row
        SELECT (F1.md).*
        FROM (SELECT ST_MetaData( raster) AS md
            FROM belgium_raster_coverage
            WHERE id = raster_id) AS F1
    ),
    coords AS (
        -- This CTE returns all the pairs (x,y) for x in [1, raster width] AND y in [1, height]
        SELECT x, y FROM metadata
        -- Generate pixel coordinates for this raster
        CROSS JOIN generate_series(0, metadata.width - 1) x
        CROSS JOIN generate_series(0, metadata.height - 1) y
    ),
    pixels AS (
        -- This CTE generates Postgis geometries representing each pixel boundary using the pixel coords (x,y)
        SELECT
            coords.x AS x,
            coords.y AS y,
            -- Build postgis geometry using raster metadata informations :
            -- scale_x : pixel width
            -- scale_y : pixel height (it is usually negative, don't ask me way, it's juste the way raster people do their stuff)
            -- upperleft(x|y) : coordinates of the upper left point
            ST_MakeEnvelope(metadata.upperleftx + coords.x * metadata.scalex,
                                                              metadata.upperlefty + coords.y * metadata.scaley ,
                                                              metadata.upperleftx + (coords.x + 1) * metadata.scalex,
                                                              metadata.upperlefty + (coords.y + 1) * metadata.scaley,
                                                              metadata.srid) AS enveloppe
            FROM coords, metadata
    ),
    values AS (
        -- This query computes the value that should be inserted into each raster pixel
        -- The result is sorted/grouped by coordinates
        SELECT pixels.x                    AS x,
               pixels.y                    AS y,
               count(pc.id) as value
        FROM pixels
        INNER JOIN all_osm_points pc
        ON ST_Intersects(pixels.enveloppe, pc.geom)
        GROUP BY x, y
        ORDER BY x, y
    ),
    flat_array AS (
        -- This CTE creates 0 value for pixels with no data
        -- X and Y coordinates are mixed, because postgis doesn't document very well if the argument 'newvalueset' is in column or row first
        -- I could have rewritten the query to take that into account, but I find it easier to mix X and Y here.
        SELECT c.y as x, c.x as y, COALESCE(v.value::double precision, 0.0) as value
        FROM coords c
        LEFT JOIN values v ON c.x = v.x and c.y = v.y
        ORDER by x, y),
    row_values AS (
        -- This CTE returns a set of rows with a single array of value for each X value
        SELECT v.x, array_agg(v.value ORDER BY v.y) AS row FROM flat_array v GROUP BY v.x
    ),
    raster_value AS (
        -- This CTE returns a single value which is a 2D array of pixel values
        select array_agg(rv.row ORDER BY rv.x) AS v FROM row_values rv
    )
    UPDATE belgium_raster_coverage set
       raster = ST_SetValues(raster, 1, 1, 1, raster_value.v)
       FROM raster_value WHERE id = raster_id;
$$;
