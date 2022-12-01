FROM ubuntu

ENV TZ Europe/Moscow
RUN mkdir /home/project
RUN mkdir /home/project/datas
WORKDIR /home/project
ENV PATH="/home/project/:${PATH}" 
RUN apt -yy update && apt -yy install git make wget build-essential curl libz-dev libncurses5-dev libbz2-dev liblzma-dev python3 unzip openjdk-11-jre && git clone https://github.com/DaehwanKimLab/hisat2.git && cd hisat2 && make && cp -r hisat2* /usr/bin
RUN wget http://ccb.jhu.edu/software/stringtie/dl/stringtie-2.2.1.tar.gz && tar xvfz stringtie-2.2.1.tar.gz && cd stringtie-2.2.1 && make release &&  cp stringtie /usr/bin
RUN wget https://github.com/samtools/samtools/releases/download/1.12/samtools-1.12.tar.bz2 && bzip2 -d samtools-1.12.tar.bz2 && tar -xf samtools-1.12.tar && cd samtools-1.12 && ./configure && make && make install
RUN wget http://ccb.jhu.edu/software/stringtie/dl/gffcompare-0.12.6.tar.gz && tar zxvf gffcompare-0.12.6.tar.gz && cd gffcompare-0.12.6/ && make && cp gffcompare /usr/bin
RUN wget http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-0.39.zip && unzip Trimmomatic-0.39.zip && mv Trimmomatic-0.39/* ./
COPY run.sh Homo* /home/project/
ENTRYPOINT ["/bin/bash"]
CMD ["run.sh"]
