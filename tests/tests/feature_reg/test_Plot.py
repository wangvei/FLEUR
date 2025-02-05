
import pytest

@pytest.mark.plot
@pytest.mark.hdf
def test_PlotDenandPot(execute_fleur, grep_number, grep_exists):
    """Plot test which checks if density and potential plottable files set up/written out correctly. The same checks are done for the vectorplot feature.

    Simple test of Fleur with two steps:
    1.Generate a starting density.
    2.Generate plottable xsf files for potential and input density. Check entries in those files.
    # TODO: maybe redesign with pytest regression
    """
    test_file_folder = './inputfiles/PlotDenandPot/'

    # Stage 1
    res_files = execute_fleur(test_file_folder, only_copy=['inp.xml'])
    res_file_names = list(res_files.keys())
    should_files = ['out']
    for file1 in should_files:
        assert (file1 in res_file_names), f'{file1} missing'

    assert ('cdn.hdf' in res_file_names) or ('cdn1' in res_file_names)

    # Stage 2
    res_files = execute_fleur(test_file_folder, only_copy=[['inp-2.xml', 'inp.xml']])
    res_file_names = list(res_files.keys())
    should_files = ['out', 'denIn_A1.xsf', 'denIn_A2.xsf', 'denIn_A3.xsf', 'denIn_f.xsf',
                    'vTot_f.xsf', 'vTot_A1.xsf', 'vTot_A2.xsf', 'vTot_A3.xsf', 'vTot_A_vec_plot.xsf',
                    'denIn_A_vec_plot.xsf']
    for file1 in should_files:
        assert (file1 in res_file_names), f'{file1} missing'
    assert ('cdn.hdf' in res_file_names) or ('cdn1' in res_file_names)

    assert grep_exists(res_files['denIn_A2.xsf'], "2.86600") #lattice constant
    assert grep_exists(res_files['denIn_A2.xsf'], "1.43300") #atom position
    #assert grep_exists(res_files['denIn_A2.xsf'], "1.55615") #line 19: 1.5561550916526704E-002
    assert grep_exists(res_files['denIn_A2.xsf'], "0.12627") #line 373: 0.12627294308505571
    assert grep_exists(res_files['denIn_A2.xsf'], "0.12725") #line 363: 0.12725278698501805


    assert grep_exists(res_files['vTot_f.xsf'], "2.86600")    #lattice constant
    assert grep_exists(res_files['vTot_f.xsf'], "1.43300")    #atom position
    assert grep_exists(res_files['vTot_f.xsf'], "4035743.16") #line 19: -4035743.1676590880
    assert grep_exists(res_files['vTot_f.xsf'], "10.44663")   #line 20: -10.446631929875359
    assert grep_exists(res_files['vTot_f.xsf'], "4.62361")    #line 129: -4.6236187704471376

    # 3D Vectorplot section
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "2.86600") #lattice constant
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "1.43300") #atom position

    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "2.229111") #line 18 first coordinate: 2.22911111111
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "0.318444") #line 21 second coordinate: 0.31844444444
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "0.015561") #line 101 second value: 0.01556155092
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "0.425758")  #line 102 third value:  0.42575826806
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "2.547555") #line 109 first coordinate: 2.54755555556

    assert grep_exists(res_files['vTot_A_vec_plot.xsf'], "2.86600") #lattice constant
    assert grep_exists(res_files['vTot_A_vec_plot.xsf'], "1.43300") #atom position

    assert grep_exists(res_files['vTot_A_vec_plot.xsf'], "0.318444") #line 12 first coordinate: 0.31844444444
    assert grep_exists(res_files['vTot_A_vec_plot.xsf'], "0.029060") #line 291 third value: -0.02906010288


@pytest.mark.plot
@pytest.mark.hdf
def test_PlotOnlyMT(execute_fleur, grep_number, grep_exists):
    """This test checks if 3D vector plots of the magnetization are generated correctly for only certain MT's.

    Simple test of Fleur with two steps:
    1.Generate a starting density.
    2.Generate plottable xsf files for input density. And check for output files.
    3.Generate plottable files of only MT's. And check for values.
    4.Generate plottable files of a certain MT. And check for values.
    """
    test_file_folder = './inputfiles/PlotOnlyMT/'

    # Stage 1
    res_files = execute_fleur(test_file_folder, only_copy=['inp.xml'])
    res_file_names = list(res_files.keys())
    should_files = ['out']
    for file1 in should_files:
        assert (file1 in res_file_names), f'{file1} missing'

    assert ('cdn.hdf' in res_file_names) or ('cdn1' in res_file_names)

    # Stage 2
    res_files = execute_fleur(test_file_folder, only_copy=[['inp-2.xml', 'inp.xml']])
    res_file_names = list(res_files.keys())
    should_files = ['out', 'denIn_A1.xsf', 'denIn_A2.xsf', 'denIn_A3.xsf', 'denIn_f.xsf',
                    'denIn_A_vec_plot.xsf']
    for file1 in should_files:
        assert (file1 in res_file_names), f'{file1} missing'
    assert ('cdn.hdf' in res_file_names) or ('cdn1' in res_file_names)


    # 3D Vectorplot section
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "2.86600") #lattice constant
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "1.43300") #atom position

    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "2.229111") #line 18 first coordinate: 2.22911111111
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "0.318444") #line 21 second coordinate: 0.31844444444
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "0.015561") #line 101 second value: 0.01556155092
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "0.425758") #line 102 third value:  0.42575826806
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "2.547555") #line 109 first coordinate: 2.54755555556

    # Stage 3
    res_files = execute_fleur(test_file_folder, only_copy=[['inp-3.xml', 'inp.xml']])
    res_file_names = list(res_files.keys())
    should_files = ['denIn_A_vec_plotOnlyMT.xsf', 'denIn_A_vec_plot.xsf']
    for file1 in should_files:
        assert (file1 in res_file_names), f'{file1} missing'

    # Grep lattice parameters
    assert grep_exists(res_files['denIn_A_vec_plotOnlyMT.xsf'], "2.86600") #lattice constant
    assert grep_exists(res_files['denIn_A_vec_plotOnlyMT.xsf'], "1.43300") #atom position

    assert grep_exists(res_files['denIn_A_vec_plotOnlyMT.xsf'], r"0\.00000000.*0\.00000000.*0\.00000000.*0\.00000000") #line 15
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "2.229111") #line 18 first coordinate: 2.22911111111
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "0.318444") #line 21 second coordinate: 0.31844444444
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "0.425758") #line 102 third value: 0.42575826806
    assert grep_exists(res_files['denIn_A_vec_plot.xsf'], "2.547555") #line 109 first coordinate: 2.54755555556

    # Stage 4
    res_files = execute_fleur(test_file_folder, only_copy=[['inp-4.xml', 'inp.xml']])
    res_file_names = list(res_files.keys())
    should_files = ['denIn_A_vec_plotOnlyCertainMT.xsf']
    for file1 in should_files:
        assert (file1 in res_file_names), f'{file1} missing'

    assert grep_exists(res_files['denIn_A_vec_plotOnlyCertainMT.xsf'], "2.86600") #lattice constant
    assert grep_exists(res_files['denIn_A_vec_plotOnlyCertainMT.xsf'], "1.43300") #atom position

    # If the wrong MT has been removed the following line will be different. This is a test stage only designed to test if the correct MT has been removed.
    assert grep_exists(res_files['denIn_A_vec_plotOnlyCertainMT.xsf'], "0.6368888.*0.955333.*1.91066.*0.0000.*0.000000.*0.0000000")
    # line 643: 0.63688888889       0.95533333333       1.91066666667       0.00000000000       0.00000000000       0.00000000000
