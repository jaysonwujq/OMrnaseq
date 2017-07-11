#!/usr/bin/env python

import luigi
from luigi.util import requires, inherits
import os
from rnaseq.utils import config
from rnaseq.modules.base_module import prepare
from rnaseq.modules.base_module import simple_task
from rnaseq.modules.base_module import collection_task

script_dir, script_name = os.path.split(os.path.abspath(__file__))
MODULE, _ = os.path.splitext(script_name)
GC_PLOT_R = os.path.join(script_dir, 'gc_plot.R')
RQ_PLOT_R = os.path.join(script_dir, 'reads_quality_plot.R')
FASTQC_SUMMERY = os.path.join(script_dir, 'fastqc_summary.py')


class fastqc_prepare(prepare):
    clean_dir = luigi.Parameter()
    _module = MODULE


@requires(fastqc_prepare)
class run_fastqc(simple_task):
    '''
    run fastqc
    '''

    sample = luigi.Parameter()
    _module = MODULE
    fastqc_dir = config.module_dir[MODULE]['fastqc']
    fastqc_bin = config.module_software[MODULE]
    fq_suffix = config.file_suffix['fq']

    def get_tag(self):
        return self.sample


@inherits(fastqc_prepare)
class fastqc_summary(simple_task):
    '''
    generate fastqc summary table
    '''

    sample_inf = luigi.Parameter()
    _module = MODULE
    _script = FASTQC_SUMMERY
    _dir=config.module_dir[MODULE]['main']

    def requires(self):
        sample_list = [each.strip().split()[1]
                       for each in open(self.sample_inf)]
        return [run_fastqc(sample=each_sample, clean_dir=self.clean_dir, proj_dir=self.proj_dir) for each_sample in sample_list]


@requires(fastqc_summary)
class gc_plot(simple_task):
    '''
    plot gc graph
    '''
    _module = MODULE
    _R = config.module_software['Rscript']
    _script = GC_PLOT_R
    _dir = config.module_dir[MODULE]['gc']


@requires(gc_plot)
class reads_quality_plot(simple_task):
    '''
    plot reads quality
    '''
    _module = MODULE
    _R = config.module_software['Rscript']
    _script = RQ_PLOT_R
    _dir = config.module_dir[MODULE]['reads_quality']


@requires(reads_quality_plot)
class fastqc_collection(collection_task):
    _module = MODULE
    pass


if __name__ == '__main__':
    luigi.run()
