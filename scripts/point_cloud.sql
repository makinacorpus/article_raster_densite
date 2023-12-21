CREATE UNLOGGED TABLE all_osm_points AS
        SELECT
        st_transform((st_dumppoints(way)).geom, 3812)::geometry(Point, 3812) AS geom FROM planet_osm_polygon
    UNION ALL
        SELECT
        st_transform((st_dumppoints(way)).geom, 3812)::geometry(Point, 3812) AS geom FROM planet_osm_line
    UNION ALL
        SELECT st_transform(way, 3812)::geometry(Point, 3812) AS geom FROM planet_osm_point;
ALTER TABLE all_osm_points ADD COLUMN id BIGSERIAL PRIMARY KEY;
CREATE INDEX ON all_osm_points USING gist(geom);
