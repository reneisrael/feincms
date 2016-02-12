FROM ubuntu:latest

# this is mostly copied from the docs, but I added ca-certificates and curl, (...)
RUN apt-get update && apt-get install -y build-essential python-dev python-pip \
    python-virtualenv libjpeg8-dev liblcms2-dev libopenjpeg-dev libwebp-dev \
    libpng12-dev libtiff4-dev libxslt1-dev libfreetype6-dev ca-certificates \
    postgresql-9.3 postgresql-server-dev-9.3 gettext npm redis-server curl git nodejs-legacy
RUN pip install virtualenv
RUN npm install -g bower jshint
RUN npm install -g gulp
RUN curl https://raw.githubusercontent.com/mitsuhiko/pipsi/master/get-pipsi.py | PIPSI_BIN_DIR=/usr/bin python

# I don't want to edit env variables there, so I just symlink pipsi's ~/.local/bin to /usr/bin
RUN mkdir ~/.local ; ln -sv /usr/bin ~/.local/bin
RUN pipsi install fabric
RUN pipsi install flake8

# Same goes for postgres.
RUN ln -sv /usr/lib/postgresql/9.3/bin/postgres /usr/bin/postgres

# Use Michal "lcamtuf" Zalewski's "fakeroot exploit" to create a "fakenoroot" LD_PRELOAD library.
# this library will be used to cheat PostgreSQL that we're not root (UID 0), but UID 1.
RUN curl 'http://lcamtuf.coredump.cx/soft/ld-expl' | sed -e 's/0/1/' -e 's/^LD/#LD/' -e 's/^rm/#rm/' | sh
RUN LD_PRELOAD=/tmp/ex.so /usr/lib/postgresql/9.3/bin/initdb /pg ; chown 1:1 -R /pg

RUN git clone https://github.com/feinheit/feincms-in-a-box && cd feincms-in-a-box && LD_PRELOAD=/tmp/ex.so PGDATA=/pg ./test.sh

# increase PostgreSQL wait delay to 10s, bind to all interfaces, set language to English
RUN sed 's/0.5/10/' -i /feincms-in-a-box/build/example_com/fabfile/__init__.py
RUN sed 's/runserver/runserver 0.0.0.0:8000/' -i /feincms-in-a-box/build/example_com/fabfile/dev.py
RUN sed -e "s/# ('es'/('es'/" -i /feincms-in-a-box/build/example_com/box/settings/common.py

# create admin account when "fab dev" runs
RUN /bin/echo -e "from django.contrib.auth.models import User;\nUser.objects.create_superuser('administrador', 'reneisrael@gmail.com', 'admin')" > /tmp/admin.py
RUN sed 's@venv/bin/python -Wall manage.py runserver@venv/bin/python -Wall manage.py shell < /tmp/admin.py ; venv/bin/python -Wall manage.py runserver@' -i \
    /feincms-in-a-box/build/example_com/fabfile/dev.py

ENTRYPOINT cd /feincms-in-a-box/build/example_com && LD_PRELOAD=/tmp/ex.so PGDATA=/pg fab dev