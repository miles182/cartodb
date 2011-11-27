# What is CartoDB? #

CartoDB is an open source tool that allows for the storage and visualization of geospatial data on the web. 

It was built to make it easier for people to tell their stories by providing them with flexible and intuitive ways to create maps and design geospatial applications. CartoDB can be installed on your own server and we also offer a hosted service at [cartodb.com](http://cartodb.com). 

If you would like to see some live demos, check out our [videos](http://www.vimeo.com/channels/cartodb) on Vimeo. We hope you like it!

<img src="http://i.imgur.com/wa3yG.jpg" width="100%"/>

# What can I do with CartoDB? #

With CartoDB, you can upload your geospatial data (Shapefiles, GeoJSON, etc) using a web form and then make it public or private. 

After it is uploaded, you can visualize it in a table or on a map, search it using SQL, and apply map styles using CartoCSS. You can even access it using the CartoDB Maps API and SQL API, or export it to a file. 

In other words, with CartoDB you can make awesome maps and build powerful geospatial applications! 

# What are the components of CartoDB? #

  - A User Interface for uploading, creating, editing, visualizing, and exporting geospatial data.
  - A geospatial database built on PostgreSQL and PostGIS 2.0
  - An SQL API for running SQL queries over HTTP with results formatted using GeoJSON and KML
  - A Map tiler that supports SQL and tile styling using CartoCSS 
  - Authentication using OAuth if required  
 
# What does CartoDB depend on? #

  - CartoDB-SQL-API  
  - Mapnik 2.0
  - NodeJS 0.4.10+
  - PostGIS 2.0
  - Postgres 9.1.x
  - Redis 2.2+
  - Ruby 1.9.2+
  - Windshaft-cartodb
  
# How do I install CartoDB? #

The installation process is fairly painless, and we have successful installations running on Amazon EC2, Linode, and development machines with OS X and Ubuntu. 

Before getting started, go ahead and download CartoDB by cloning this repository:

```bash
git clone https://github.com/Vizzuality/cartodb.git
```

Or you can just [download the CartoDB zip file](https://github.com/Vizzuality/cartodb/zipball/master).

## Install Ruby ##

We implemented CartoDB in the [Ruby](ruby-lang.org) programming language, so you'll need to install Ruby 1.9.2+.

## Install Node.js ##

Components of CartoDB, like Windshaft, depend on [Node.js](nodejs.org). Basically it's a highly-scalable web server that leverages Google's V8 JavaScript engine. 

You can install Node.js and NPM (the Node.js package manager) by [following these instructions](https://github.com/joyent/node/wiki/Installation) on Node's GitHub wiki site. 

Alternatively, you can install Node.js using `brew install node`, but NPM has to be installed using the wiki instructions above.

## Install PostgreSQL and PostGIS ##

[PostgreSQL](http://www.postgresql.org) is the relational database that powers CartoDB. [PostGIS](http://postgis.refractions.net) is the geospatial extension that allows PostgreSQL to support geospatial queries. This is the heart of CartoDB!

First you'll need to install a few dependencies. 

  - [GDAL](http://www.gdal.org) is requires for raster support.
  - [GEOS](http://trac.osgeo.org/geos) is required for geometry function support.
  - [JSON-C](http://oss.metaparadigm.com/json-c) is required for GeoJSON support.
  - [PROJ4](http://trac.osgeo.org/proj) is required for reprojection support.
  - plpython is required for Python support (e.g., `sudo apt-get install postgresql-plpython-9.1`)

 
Next install PostgreSQL 9.1.x and PostGIS 2.0.x.

Finally, CartoDB depends on a geospatial database template named `template_postgis`. In the example script below, make sure that the path to each SQL file is correct. As of PostGIS r8242 for example, spatial_ref_sys.sql is now located in the `root` installation directory, instead of in the `./postgis` directory:

```bash
#!/usr/bin/env bash
POSTGIS_SQL_PATH='pg_config --sharedir'/contrib/postgis-2.0
createdb -E UTF8 template_postgis 
createlang -d template_postgis plpgsql 
psql -d postgres -c "UPDATE pg_database SET datistemplate='true' WHERE datname='template_postgis';"
psql -d template_postgis -f $POSTGIS_SQL_PATH/postgis.sql 
psql -d template_postgis -f $POSTGIS_SQL_PATH/spatial_ref_sys.sql
psql -d template_postgis -f $POSTGIS_SQL_PATH/legacy.sql
psql -d template_postgis -f $POSTGIS_SQL_PATH/legacy_compatibility_layer.sql
psql -d template_postgis -c "GRANT ALL ON geometry_columns TO PUBLIC;" 
psql -d template_postgis -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"
```

## Install Redis ##

Components of CartoDB, like Windshaft, depend on [Redis](http://redis.io). Basically it's a really fast key-value datastore used for caching.

To install Redis 2.2+, You can [download it here](http://redis.io/download) or you can use `brew install redis`.
  
## Install Python dependencies ##

To install the Python modules that CartoDB depends on, you can use `easy_install`, which is easy!

```bash
easy_install pip 
pip install -r python_requirements.txt
```      

If this fails, try doing `export ARCHFLAGS='-arch i386 -arch x86_64'` beforehand.

## Setup hosts ##

For development and testing, edit `/etc/hosts` with the following lines:
``` 
127.0.0.1 admin.localhost.lan admin.testhost.lan
127.0.0.1 my_subdomain.localhost.lan
```

## Install Mapnik ##

Mapnik is an API for creating beautiful maps. CartoDB uses Mapnik 2.0.x for creating and syling map tiles. 

To install it using Ubuntu:


```bash
sudo apt-get install build-essential curl wget python-software-properties
sudo add-apt-repository ppa:mapnik/nightly-trunk
sudo apt-get update
sudo apt-get install libmapnik2 libmapnik2-dev mapnik2-utils
```

To install it using OS X, here is a nice [Homebre recipe](http://trac.mapnik.org/wiki/MacInstallation/Homebrew).

## Install CartoDB SQL API ##

The CartoDB SQL API component powers the SQL queries over HTTP. To install it:
    
```bash            
git clone git@github.com:Vizzuality/CartoDB-SQL-API.git
cd CartoDB-SQL-API
npm install
```

To run CartoDB SQL API in development mode, simply type:

```bash
node app.js development
```

## Install Windshaft-cartodb ##

The Windshaft-cartodb component powers the CartoDB Maps API. To install it:

```bash
git clone git@github.com:Vizzuality/Windshaft-cartodb.git
cd Windshaft-cartodb
npm install
```
To run Windshaft-cartodb in development mode, simply type:

```bash
node app.js development
```

## Install local instance of cold beer ##

Congratulations! Everything you need should now be installed. Celebrate by drinking a cold beer before continuing. :)


# Running CartoDB #

Time to run your development version of CartoDB.

First, there are a couple of one-time setups:

  - Go into the `cartodb` directory.
  - Type `rvm` and say "yes" to create a new gemset or just type `rvm use 1.9.2@cartodb --create`
  - Type `bundle install --binstubs`
  - Rename `config/app_config.yml.sample` to `config/app_config.yml`
  - Rename `config/database.yml.sample` to `config/database.yml`

After that, just make sure CartoDB-SQL-API, Windshaft-cartodb, and Redis are all running. 

Next, setup your first user account:

```bash
bundle exec rake cartodb:db:setup EMAIL=me@mail.com SUBDOMAIN=my_subdomain PASSWORD=my_pass ADMIN_PASSWORD=my_pass
bundle exec rake cartodb:db:set_user_quota['me',1000] # 1 GB quota
```

That's it! 

You should now be able to access `my_subdomain.localhost.lan` in your browser and login with your email and password!

Note: Look at the `public/javascripts/environments/development.js` file which configures Windshaft-cartodb tile server URLs. 

  
### Contributors by commits###

  - Fernando Blat (@ferblape)
  - Javier Alvarez (@xavijam)
  - Simon Tokumine (@tokumine)
  - Javier Álvarez Medina (@xavijam)
  - Alvaro Bautista (@batu)
  - Fernando Espinosa (@ferdev)
  - Sergio Alvarez Leiva (@saleiva)
  - Javier de la Torre (@jatorre)
  - Andrew W Hill (@andrewxhill)
  - Javier Arce (@javierarce)
  - Aaron Steele (@eightysteele)